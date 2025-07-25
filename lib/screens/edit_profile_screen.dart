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

  File? _newImage;
  String? _firstName;
  String? _lastName;
  String? _username;
  String? _photoUrl;

  bool _isLoading = true;
  bool _isUploadingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();

    setState(() {
      _firstName = data?['firstName'] ?? '';
      _lastName = data?['lastName'] ?? '';
      _username = data?['username'] ?? '';
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
      print('Image upload failed: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;
    String? imageUrl = _photoUrl;

    try {
      if (_newImage != null) {
        imageUrl = await _uploadImage(_newImage!);
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'firstName': _firstName!.trim(),
        'lastName': _lastName!.trim(),
        // Username intentionally not updated
        'photoUrl': imageUrl,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = "Failed to save profile");
      print("Error saving profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text("Edit Profile", style: textTheme.titleMedium),
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundImage: _newImage != null
                                  ? FileImage(_newImage!)
                                  : (_photoUrl != null && _photoUrl!.isNotEmpty)
                                      ? NetworkImage(_photoUrl!) as ImageProvider
                                      : null,
                              backgroundColor: colorScheme.surface,
                              child: (_newImage == null &&
                                      (_photoUrl == null || _photoUrl!.isEmpty))
                                  ? Icon(Icons.person,
                                      color: colorScheme.onSurface, size: 44)
                                  : null,
                            ),
                            if (_isUploadingImage)
                              const SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(color: colorScheme.error)),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      initialValue: _firstName ?? "",
                      style: TextStyle(color: colorScheme.onBackground),
                      decoration: _inputDecoration(context, 'First Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                      onSaved: (value) => _firstName = value,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _lastName ?? "",
                      style: TextStyle(color: colorScheme.onBackground),
                      decoration: _inputDecoration(context, 'Last Name'),
                      onSaved: (value) => _lastName = value,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _username ?? "",
                      enabled: false,
                      style: TextStyle(
                        color: colorScheme.onBackground.withOpacity(0.6),
                      ),
                      decoration: _inputDecoration(context, 'Username').copyWith(
                        // No lock icon used
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isUploadingImage ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text("Save"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InputDecoration(
      labelText: label,
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface.withOpacity(0.7),
      ),
      filled: true,
      fillColor: colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
