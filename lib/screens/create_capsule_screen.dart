import 'dart:io';

import 'package:boxed_app/widgets/collaborator_picker_dialog.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/user_crypto_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateCapsuleScreen extends StatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  State<CreateCapsuleScreen> createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _isLoading = false;

  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  int? _selectedBackground;

  final List<String> _backgroundOptions = [
    'assets/basic_background1.jpg',
    'assets/basic_background2.webp',
    'assets/basic_background3.jpg',
  ];

  final List<Map<String, dynamic>> _collaborators = [];

  // ───────────── SAFE SESSION CHECK ─────────────
  bool _hasUserMasterKey() {
    try {
      UserCryptoState.userMasterKey;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage();
    setState(() {
      _selectedImages.addAll(picked.map((x) => File(x.path)));
    });
  }

  void _removeImage(File file) {
    setState(() => _selectedImages.remove(file));
  }

  Future<void> _openCollaboratorPicker() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => const CollaboratorPickerDialog(),
    );

    if (result != null) {
      setState(() {
        _collaborators
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _createCapsule() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null ||
        _nameController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    // 🔐 HARD STOP if session expired
    if (!_hasUserMasterKey()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
        ),
      );

      Navigator.of(context).pop();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // 1️⃣ Keys (keep your existing flow)
      final userMasterKey = UserCryptoState.userMasterKey;

      final capsuleKey =
          await BoxedEncryptionService.generateCapsuleKey();

      final encryptedCapsuleKey =
          await BoxedEncryptionService.encryptCapsuleKeyForUser(
        capsuleKey: capsuleKey,
        userMasterKey: userMasterKey,
      );

      // 2️⃣ Collaborator IDs (new schema)
      // creator + selected collaborators
      final List<String> collaboratorIds = [
        user.uid,
        ..._collaborators.map((c) => c['userId'] as String),
      ];

      // 3️⃣ New status model
      // - no collaborators => active (user can add memories)
      // - with collaborators => pending (wait for accept)
      final String status =
          _collaborators.isNotEmpty ? 'pending' : 'active';

      // 4️⃣ Create capsule doc (NEW SCHEMA)
      final capsuleRef = firestore.collection('capsules').doc();
      final capsuleId = capsuleRef.id;

      final Map<String, dynamic> roles = {
        user.uid: 'editor',
        for (final c in _collaborators)
          (c['userId'] as String): (c['role'] ?? 'editor').toString().toLowerCase(),
      };

      await capsuleRef.set({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorId': user.uid,
        'unlockDate': Timestamp.fromDate(_selectedDateTime!.toUtc()),
        'collaboratorIds': collaboratorIds,
        'roles': roles,
        // Keep encrypted key store as-is (creator only for now)
        'capsuleKeys': {user.uid: encryptedCapsuleKey},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': status,
        'emoji': '🎁',
        'backgroundId': _selectedBackground,
        'isSurprise': false,
      });

      // 5️⃣ Create collaboration requests (NEW FLOW)
      // One request per collaborator (excluding creator)
      if (_collaborators.isNotEmpty) {
        final batch = firestore.batch();
        for (final c in _collaborators) {
          final toUserId = c['userId'] as String;
          final reqRef = firestore.collection('collaboration_requests').doc();

          batch.set(reqRef, {
            'capsuleDraftId': capsuleId,
            'fromUserId': user.uid,
            'toUserId': toUserId,
            'role': (c['role'] ?? 'editor').toString().toLowerCase(),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // 6️⃣ Images -> store in Storage + add memory docs (NEW memory fields)
      for (final image in _selectedImages) {
        final filename =
            DateTime.now().millisecondsSinceEpoch.toString();
        final ref =
            storage.ref('capsules/$capsuleId/$filename.jpg');

        final upload = await ref.putFile(image);
        final url = await upload.ref.getDownloadURL();

        // Note: Your Firestore rules allow memory writes only when status == "active".
        // If capsule is "pending", this write would fail.
        // So we only write memories immediately if status == active (solo capsule).
        if (status == 'active') {
          await capsuleRef.collection('memories').add({
            'type': 'image',
            'content': url,
            'createdBy': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 7️⃣ Encrypted note -> memory doc (only if status == active)
      if (status == 'active' && _noteController.text.trim().isNotEmpty) {
        final encryptedNote =
            await BoxedEncryptionService.encryptData(
          plainText: _noteController.text.trim(),
          capsuleKey: capsuleKey,
        );

        await capsuleRef.collection('memories').add({
          'type': 'text',
          'content': encryptedNote, // encrypted payload stored in content
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isEncrypted': true, // optional flag for your UI
        });
      }

      // 8️⃣ UX message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'pending'
                ? 'Capsule created! Invite sent to collaborators.'
                : 'Capsule created!',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ───────────── UI (UNCHANGED) ─────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('🎁 Create Capsule')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _input(_nameController, 'Capsule name'),
            _input(_descriptionController, 'Description', maxLines: 3),
            const SizedBox(height: 12),
            GestureDetector(onTap: _selectDate, child: _dateTile()),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openCollaboratorPicker,
              icon: const Icon(Icons.group_add),
              label: const Text('Add Collaborators'),
            ),
            const SizedBox(height: 16),
            _input(_noteController, 'Write a note', maxLines: 3),
            const SizedBox(height: 16),
            _imagePicker(colorScheme),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createCapsule,
                      child: const Text('Create Capsule'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _selectedDateTime == null
              ? 'Pick unlock date'
              : 'Opens on $_selectedDateTime',
        ),
      );

  Widget _input(TextEditingController c, String hint, {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  Widget _imagePicker(ColorScheme scheme) => Wrap(
        spacing: 8,
        children: [
          ..._selectedImages.map(
            (img) => Stack(
              children: [
                Image.file(
                  img,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _removeImage(img),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outline),
              ),
              child: const Icon(Icons.add_a_photo),
            ),
          ),
        ],
      );
}
