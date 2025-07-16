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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
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
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
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
        'username': _username!.trim(),
        'photoUrl': imageUrl,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated!")),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = "Failed to save profile");
      print("Error saving profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: _newImage != null
                                ? FileImage(_newImage!)
                                : (_photoUrl != null && _photoUrl!.isNotEmpty)
                                    ? NetworkImage(_photoUrl!) as ImageProvider
                                    : null,
                            backgroundColor: Colors.grey[800],
                            child: (_newImage == null && (_photoUrl == null || _photoUrl!.isEmpty))
                                ? const Icon(Icons.person, color: Colors.white, size: 50)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: _pickImage,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      initialValue: _firstName ?? "",
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('First Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Required' : null,
                      onSaved: (value) => _firstName = value,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _lastName ?? "",
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Last Name'),
                      onSaved: (value) => _lastName = value,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _username ?? "",
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Username'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Required' : null,
                      onSaved: (value) => _username = value,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[850],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}
