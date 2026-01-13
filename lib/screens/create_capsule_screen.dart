<<<<<<< HEAD
=======
import 'package:boxed_app/services/boxed_encryption_service.dart';
>>>>>>> fc5ef48 (removed upload images feature)
import 'package:boxed_app/state/user_crypto_state.dart';
import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:provider/provider.dart';
import 'package:boxed_app/controllers/capsule_controller.dart';
=======
>>>>>>> fc5ef48 (removed upload images feature)

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
  int? selectedBackground;

<<<<<<< HEAD
  final List<String> backgroundOptions = [
    'assets/basic/background1.jpg',
    'assets/basic/background2.webp',
    'assets/basic/background3.jpg',
  ];

  Future<void> selectDate() async {
=======
  DateTime? _selectedDateTime;
  bool _isLoading = false;

  int? _selectedBackground;

  final List<String> _backgroundOptions = [
    'assets/basic_background1.jpg',
    'assets/basic_background2.webp',
    'assets/basic_background3.jpg',
  ];

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
>>>>>>> fc5ef48 (removed upload images feature)
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

<<<<<<< HEAD
  Future<void> createCapsule() async {
=======
  Future<void> _createCapsule() async {
>>>>>>> fc5ef48 (removed upload images feature)
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

    setState(() => isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

<<<<<<< HEAD
      // ✅ Must have master key to encrypt capsule key for storage
      final userMasterKey = UserCryptoState.userMasterKeyOrNull;
      if (userMasterKey == null) {
        throw Exception('Master key missing. Please log in again.');
      }
=======
      // Master key (already initialized at login / app startup)
      final userMasterKey = UserCryptoState.userMasterKey;
>>>>>>> fc5ef48 (removed upload images feature)

      // Generate capsule key (used to encrypt memories/notes)
      final capsuleKey = await BoxedEncryptionService.generateCapsuleKey();

<<<<<<< HEAD
      // ✅ Encrypt capsule key for this user (stored in Firestore)
=======
      // Encrypt capsule key for this user (stored in Firestore)
>>>>>>> fc5ef48 (removed upload images feature)
      final encryptedCapsuleKey =
          await BoxedEncryptionService.encryptCapsuleKeyForUser(
        capsuleKey: capsuleKey,
        userMasterKey: userMasterKey,
      );

<<<<<<< HEAD
      // Solo capsule - always active, no collaborators
      final capsuleRef = firestore.collection('capsules').doc();
      final capsuleId = capsuleRef.id;

      // Create capsule doc (SOLO schema)
      await capsuleRef.set({
        'capsuleId': capsuleId,
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'creatorId': user.uid,
        'unlockDate': Timestamp.fromDate(selectedDateTime!.toUtc()),
        'capsuleKeys': {user.uid: encryptedCapsuleKey}, // ✅ encrypted SecretBox
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'emoji': '',
        'backgroundId': selectedBackground,
        'isSurprise': false,
      });

      // Encrypted note as memory (text-only)
      if (noteController.text.trim().isNotEmpty) {
        final encryptedNote = await BoxedEncryptionService.encryptData(
          plainText: noteController.text.trim(),
=======
      // Create capsule doc (SOLO schema)
      final capsuleRef = firestore.collection('capsules').doc();
      final capsuleId = capsuleRef.id;

      await capsuleRef.set({
        'capsuleId': capsuleId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorId': user.uid,
        'unlockDate': Timestamp.fromDate(_selectedDateTime!.toUtc()),
        'capsuleKeys': {user.uid: encryptedCapsuleKey},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'emoji': '🎁',
        'backgroundId': _selectedBackground,
        'isSurprise': false,
      });

      // Encrypted note -> memory doc (optional)
      if (_noteController.text.trim().isNotEmpty) {
        final encryptedNote = await BoxedEncryptionService.encryptData(
          plainText: _noteController.text.trim(),
>>>>>>> fc5ef48 (removed upload images feature)
          capsuleKey: capsuleKey,
        );

        await capsuleRef.collection('memories').add({
          'type': 'text',
          'content': encryptedNote,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isEncrypted': true,
        });
      }

<<<<<<< HEAD
      if (mounted) {
        Navigator.of(context).pop();
        context.read<CapsuleController>().loadCapsules(user.uid);
      }
=======
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capsule created!')),
      );

      Navigator.pop(context);
>>>>>>> fc5ef48 (removed upload images feature)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

<<<<<<< HEAD
=======
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ───────────── UI ─────────────

>>>>>>> fc5ef48 (removed upload images feature)
  @override
  Widget build(BuildContext context) {
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
            GestureDetector(onTap: selectDate, child: _dateTile()),
            const SizedBox(height: 16),
<<<<<<< HEAD
            _input(noteController, 'Write a note (optional)', maxLines: 3),
=======
            _input(_noteController, 'Write a note', maxLines: 3),
>>>>>>> fc5ef48 (removed upload images feature)
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

  Widget _input(
    TextEditingController c,
    String hint, {
    int maxLines = 1,
  }) {
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

<<<<<<< HEAD
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
=======
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
>>>>>>> fc5ef48 (removed upload images feature)
}
