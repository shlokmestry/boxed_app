import 'package:boxed_app/core/services/boxed_encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateCapsuleScreen extends StatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  State<CreateCapsuleScreen> createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  static const double _fontSize = 15;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectUnlockDateTime() async {
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

  String _unlockDateLabel() {
    final dt = _selectedDateTime;
    if (dt == null) return 'Select';
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  Future<void> _createCapsule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    if (_selectedDateTime!
        .isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock time must be in the future.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      final userMasterKey = UserCryptoState.userMasterKeyOrNull;
      if (userMasterKey == null) {
        throw Exception('Master key missing. Please log in again.');
      }

      final capsuleKey = await BoxedEncryptionService.generateCapsuleKey();

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
        'emoji': '📦',
        'isSurprise': false,
      });

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
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TextStyle get _baseTextStyle => const TextStyle(
        fontSize: _fontSize,
        fontWeight: FontWeight.w500,
      );

  Widget _sectionTitle(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: _baseTextStyle.copyWith(
          color: colorScheme.onBackground.withOpacity(0.85),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      color: colorScheme.outline.withOpacity(0.12),
    );
  }

  Widget _textRowField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? hint,
    required String? Function(String?) validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: _baseTextStyle.copyWith(color: colorScheme.onSurface),
        cursorColor: colorScheme.primary,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint ?? label,
          hintStyle: _baseTextStyle.copyWith(
            color: colorScheme.onSurface.withOpacity(0.45),
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _unlockRow() {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _isLoading ? null : _selectUnlockDateTime,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Unlock date',
                style: _baseTextStyle.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    _unlockDateLabel(),
                    style: _baseTextStyle.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: colorScheme.onSurface.withOpacity(0.75),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatingCreateButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        top: 14,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white, // keep buttons white
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), // less pill
              ),
            ),
            onPressed: _isLoading ? null : _createCapsule,
            child: _isLoading
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Text(
                    'Create Capsule',
                    style: _baseTextStyle.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Capsule'),
        centerTitle: true,
      ),
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            children: [
              Text(
                'Create a capsule that opens in the future.',
                style: _baseTextStyle.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 14),

              _sectionTitle('Details'),
              _card(
                children: [
                  _textRowField(
                    label: 'Capsule name',
                    controller: _nameController,
                    hint: 'Capsule name',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Capsule name is required.';
                      }
                      return null;
                    },
                  ),
                  _divider(),
                  _textRowField(
                    label: 'Description',
                    controller: _descriptionController,
                    maxLines: 3,
                    hint: 'Description',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Description is required.';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _sectionTitle('Unlock'),
              _card(
                children: [
                  _unlockRow(),
                ],
              ),

              const SizedBox(height: 14),

              _sectionTitle('Note'),
              _card(
                children: [
                  _textRowField(
                    label: 'Write a note',
                    controller: _noteController,
                    maxLines: 3,
                    hint: 'Write a note',
                    validator: (_) => null, // no optional/required labels
                  ),
                ],
              ),

              // Button is part of the scroll (not pinned), but styled to feel floating.
              _floatingCreateButton(),
            ],
          ),
        ),
      ),
    );
  }
}
