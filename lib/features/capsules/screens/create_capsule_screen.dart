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

  final GlobalKey<TooltipState> _helpTipKey = GlobalKey<TooltipState>();

  static const int _maxDescriptionLength = 200;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      setState(() {}); // Update character count
    });
  }

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              surface: Color(0xFF2A2A2A),
              background: Colors.black,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              surface: Color(0xFF2A2A2A),
              background: Colors.black,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
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

  String _formatUnlockDate() {
    final dt = _selectedDateTime;
    if (dt == null) return '01/02/2026';
    return DateFormat('MM/dd/yyyy').format(dt.toLocal());
  }

  Future<void> _createCapsule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again.'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields.'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }

    if (_selectedDateTime!
        .isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unlock time must be in the future.'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
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
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFF2A2A2A),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _descriptionCharCount => _descriptionController.text.length;

  TextStyle get _labelStyle => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.2,
      );

  TextStyle get _inputStyle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Colors.white,
        height: 1.5,
      );

  TextStyle get _hintStyle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Color(0xFF6B7280),
        height: 1.5,
      );

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    bool showCounter = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: _inputStyle,
          cursorColor: Colors.white,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            hintText: hint,
            hintStyle: _hintStyle,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            errorStyle: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
          validator: validator,
        ),
        if (showCounter)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Maximum $_maxDescriptionLength characters',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  '$_descriptionCharCount/$_maxDescriptionLength',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Capsule Unlock Date', style: _labelStyle),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _selectUnlockDateTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatUnlockDate(),
                    style: _selectedDateTime == null ? _hintStyle : _inputStyle,
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF6B7280),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      
      ],
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _createCapsule,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Create Capsule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Capsule',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
  Tooltip(
    key: _helpTipKey,
    triggerMode: TooltipTriggerMode.manual, // show it yourself
    message: 'Name it, set an unlock date, then seal it.\nIt stays locked until the unlock day.',
    enableTapToDismiss: true,
    preferBelow: true,
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(12),
    ),
    textStyle: const TextStyle(color: Color(0xFF9CA3AF), height: 1.35),
    child: IconButton(
      icon: const Icon(Icons.help_outline, color: Colors.white),
      onPressed: () => _helpTipKey.currentState?.ensureTooltipVisible(),
    ),
  ),
],


      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildInputField(
                      label: 'Capsule Name',
                      controller: _nameController,
                      hint: 'Name it like a movie trailer',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Capsule name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: 'Description',
                      controller: _descriptionController,
                      hint: 'What belongs in here? Be specific. Be brave.',
                      maxLines: 4,
                      maxLength: _maxDescriptionLength,
                      showCounter: true,
                      validator: null,
                    ),
                    const SizedBox(height: 20),
                    _buildDateField(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom button
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                child: _buildCreateButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}