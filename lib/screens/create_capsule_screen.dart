import 'dart:io';

import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/user_crypto_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/controllers/capsule_controller.dart';

class CreateCapsuleScreen extends StatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  State<CreateCapsuleScreen> createState() => CreateCapsuleScreenState();
}

class CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final noteController = TextEditingController();
  DateTime? selectedDateTime;
  bool isLoading = false;
  final List<File> selectedImages = [];
  final ImagePicker picker = ImagePicker();
  int? selectedBackground;
  final List<String> backgroundOptions = [
    'assets/basic/background1.jpg',
    'assets/basic/background2.webp',
    'assets/basic/background3.jpg',
  ];

  bool get isCryptoReady {
    try {
      UserCryptoState.userMasterKey;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> selectDate() async {
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
      selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> pickImages() async {
    final picked = await picker.pickMultiImage();
    setState(() {
      selectedImages.addAll(picked?.map((x) => File(x.path)) ?? []);
    });
  }

  void removeImage(File file) {
    setState(() {
      selectedImages.remove(file);
    });
  }

  Future<void> createCapsule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        nameController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty ||
        selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    if (!isCryptoReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Encryption not ready yet. Please restart the app.')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // Generate keys (keep your existing crypto flow)
      final userMasterKey = UserCryptoState.userMasterKey;
      final capsuleKey = await BoxedEncryptionService.generateCapsuleKey();
      final encryptedCapsuleKey = await BoxedEncryptionService.encryptCapsuleKeyForUser(
        capsuleKey: capsuleKey,
        userMasterKey: userMasterKey,
      );

      // Solo capsule - always active, no collaborators
      final capsuleRef = firestore.collection('capsules').doc();
      final capsuleId = capsuleRef.id;

      // Create capsule doc (SOLO schema)
      await capsuleRef.set({
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'creatorId': user.uid,
        'unlockDate': Timestamp.fromDate(selectedDateTime!.toUtc()),
        'capsuleKeys': {user.uid: encryptedCapsuleKey},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'emoji': '🔒',
        'backgroundId': selectedBackground,
        'isSurprise': false,
      });

      // Upload images as memories (always possible since solo)
      for (final image in selectedImages) {
        final filename = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = storage.ref('capsules/$capsuleId/$filename.jpg');
        final upload = await ref.putFile(image);
        final url = await upload.ref.getDownloadURL();
        await capsuleRef.collection('memories').add({
          'type': 'image',
          'content': url,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Encrypted note as memory
      if (noteController.text.trim().isNotEmpty) {
        final encryptedNote = await BoxedEncryptionService.encryptData(
          plainText: noteController.text.trim(),
          capsuleKey: capsuleKey,
        );
        await capsuleRef.collection('memories').add({
          'type': 'text',
          'content': encryptedNote,  // Encrypted payload
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isEncrypted': true,
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
        context.read<CapsuleController>().loadCapsules(user.uid);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Capsule')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _input(nameController, 'Capsule name'),
            _input(descriptionController, 'Description', maxLines: 3),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: selectDate,
              child: _dateTile(),
            ),
            const SizedBox(height: 16),
            _input(noteController, 'Write a note (optional)', maxLines: 3),
            const SizedBox(height: 16),
            _imagePicker(colorScheme),
            const SizedBox(height: 24),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: createCapsule,
                  child: const Text('Create Capsule'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        selectedDateTime == null
            ? 'Pick unlock date'
            : 'Opens on ${selectedDateTime!.toLocal()}',
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _imagePicker(ColorScheme scheme) {
    return Wrap(
      spacing: 8,
      children: [
        ...selectedImages.map((img) => Stack(
              children: [
                Image.file(img, width: 80, height: 80, fit: BoxFit.cover),
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => removeImage(img),
                  ),
                ),
              ],
            )),
        GestureDetector(
          onTap: pickImages,
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
}
