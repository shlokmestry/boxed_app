import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controllers for text fields
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();

  File? _newImage;
  String? _photoUrl;

  bool _isLoading = true;
  bool _isUploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();

    setState(() {
      final firstName = data?['firstName'] ?? '';
      final lastName = data?['lastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();

      _fullNameController.text = fullName;
      _emailController.text = user.email ?? '';
      _usernameController.text = data?['username'] ?? '';
      _photoUrl = data?['photoUrl'];
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _newImage = File(picked.path));
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid-${DateTime.now().millisecondsSinceEpoch}.jpg');

      setState(() => _isUploadingImage = true);
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      setState(() => _isUploadingImage = false);
      return downloadUrl;
    } catch (e) {
      setState(() => _isUploadingImage = false);
      // ignore: avoid_print
      print('Image upload failed: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    String? imageUrl = _photoUrl;

    try {
      if (_newImage != null) {
        imageUrl = await _uploadImage(_newImage!);
      }

      // Split full name into first and last name
      final fullName = _fullNameController.text.trim();
      final nameParts = fullName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final newEmail = _emailController.text.trim();
      final newUsername = _usernameController.text.trim();

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'firstName': firstName,
        'lastName': lastName,
        'username': newUsername,
        'photoUrl': imageUrl,
      });

      // Update Firebase Auth email if changed
      if (newEmail != user.email && newEmail.isNotEmpty) {
        try {
          await user.verifyBeforeUpdateEmail(newEmail);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Verification email sent. Please verify to complete email change.',
              ),
              backgroundColor: Color(0xFF2A2A2A),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email update failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // Update display name in Firebase Auth
      await user.updateDisplayName(fullName);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = "Failed to save profile");
      // ignore: avoid_print
      print("Error saving profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getInitials() {
    final fullName = _fullNameController.text;
    if (fullName.isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    const bg = Colors.black;
    const surface = Color(0xFF1F2937); // consistent dark surface
    const labelColor = Color(0xFF9CA3AF);
    const hintColor = Color(0xFF6B7280);
    const borderColor = Color(0xFF374151);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Profile avatar
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: surface, // consistent avatar bg
                                  image: _newImage != null
                                      ? DecorationImage(
                                          image: FileImage(_newImage!),
                                          fit: BoxFit.cover,
                                        )
                                      : (_photoUrl != null &&
                                              _photoUrl!.isNotEmpty)
                                          ? DecorationImage(
                                              image: NetworkImage(_photoUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                    width: 1,
                                  ),
                                ),
                                child: (_newImage == null &&
                                        (_photoUrl == null ||
                                            _photoUrl!.isEmpty))
                                    ? Center(
                                        child: Text(
                                          _getInitials(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            if (_isUploadingImage)
                              const SizedBox(
                                width: 100,
                                height: 100,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _pickImage,
                        child: Text(
                          'Change Profile Photo',
                          style: TextStyle(
                            color: colorScheme.primary, // primary color
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _buildInputField(
                        label: 'Full Name',
                        controller: _fullNameController,
                        hintText: 'Enter your full name',
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                        fillColor: surface,
                        labelColor: labelColor,
                        hintColor: hintColor,
                        borderColor: borderColor,
                        focusColor: colorScheme.primary,
                      ),

                      const SizedBox(height: 16),

                      _buildInputField(
                        label: 'Email',
                        controller: _emailController,
                        hintText: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (!value.contains('@')) {
                            return 'Invalid email';
                          }
                          return null;
                        },
                        fillColor: surface,
                        labelColor: labelColor,
                        hintColor: hintColor,
                        borderColor: borderColor,
                        focusColor: colorScheme.primary,
                      ),

                      const SizedBox(height: 16),

                      _buildInputField(
                        label: 'Username',
                        controller: _usernameController,
                        hintText: 'Enter your username',
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                        fillColor: surface,
                        labelColor: labelColor,
                        hintColor: hintColor,
                        borderColor: borderColor,
                        focusColor: colorScheme.primary,
                      ),

                      const SizedBox(height: 40),

                      // Update Profile button (outlined; fixed disabled border issue)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed:
                              (_isUploadingImage || _isLoading) ? null : _saveProfile,
                          style: ButtonStyle(
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            foregroundColor:
                                MaterialStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return Colors.white.withOpacity(0.5);
                                }
                                return Colors.white;
                              },
                            ),
                            side:
                                MaterialStateProperty.resolveWith<BorderSide>(
                              (states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return BorderSide(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 1.5,
                                  );
                                }
                                return const BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                );
                              },
                            ),
                          ),
                          child: Text(
                            _isLoading ? 'Saving...' : 'Update Profile',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required Color fillColor,
    required Color labelColor,
    required Color hintColor,
    required Color borderColor,
    required Color focusColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            hintText: hintText,
            hintStyle: TextStyle(
              color: hintColor,
              fontSize: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
