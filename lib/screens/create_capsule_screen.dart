import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/user_crypto_state.dart';

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

  int? _selectedBackgroundId;

  final List<String> _backgroundOptions = const [
    'assets/basic/background1.jpg',
    'assets/basic/background2.webp',
    'assets/basic/background3.jpg',
  ];

  Future<void> _selectDateTime() async {
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

  Future<void> _createCapsule() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnack('Please sign in again.');
      return;
    }

    if (_nameController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedDateTime == null) {
      _showSnack('Please complete all fields.');
      return;
    }

    final userMasterKey = UserCryptoState.userMasterKeyOrNull;
    if (userMasterKey == null) {
      _showSnack('Master key missing. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Generate capsule key (used to encrypt memories/notes)
      final capsuleKey = await BoxedEncryptionService.generateCapsuleKey();

      // Encrypt capsule key for this user (stored in Firestore)
      final encryptedCapsuleKey =
          await BoxedEncryptionService.encryptCapsuleKeyForUser(
        capsuleKey: capsuleKey,
        userMasterKey: userMasterKey,
      );

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
        'backgroundId': _selectedBackgroundId,
        'isSurprise': false,
      });

      // Optional: initial note stored as encrypted text memory
      final note = _noteController.text.trim();
      if (note.isNotEmpty) {
        final encryptedNote = await BoxedEncryptionService.encryptData(
          plainText: note,
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

      if (!mounted) return;
      _showSnack('Capsule created!');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
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
            _input(_nameController, 'Capsule name'),
            _input(_descriptionController, 'Description', maxLines: 3),
            const SizedBox(height: 12),
            GestureDetector(onTap: _selectDateTime, child: _dateTile()),
            const SizedBox(height: 16),
            Text(
              'Background (optional)',
              style: TextStyle(
                color: colorScheme.onBackground.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _backgroundPicker(),
            const SizedBox(height: 16),
            _input(_noteController, 'Write a note (optional)', maxLines: 3),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
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

  Widget _dateTile() {
    final colorScheme = Theme.of(context).colorScheme;

    final label = _selectedDateTime == null
        ? 'Pick unlock date'
        : 'Unlocks on: ${DateFormat.yMMMd().add_jm().format(_selectedDateTime!.toLocal())}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundPicker() {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _backgroundOptions.length + 1, // + "None"
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final bool isNone = i == 0;
          final int? bgId = isNone ? null : i - 1;
          final bool selected = _selectedBackgroundId == bgId;

          return InkWell(
            onTap: () => setState(() => _selectedBackgroundId = bgId),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outline.withOpacity(0.35),
                  width: selected ? 2 : 1,
                ),
                color: colorScheme.surface,
              ),
              clipBehavior: Clip.antiAlias,
              child: isNone
                  ? Center(
                      child: Text(
                        'None',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Image.asset(
                      _backgroundOptions[bgId!],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          'Missing',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
