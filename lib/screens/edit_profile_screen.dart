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

    if (data != null) {
      setState(() {
        _firstName = data['firstName'] ?? '';
        _lastName = data['lastName'] ?? '';
        _username = data['username'] ?? '';
        _photoUrl = data['photoUrl'];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _newImage = File(picked.path));
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Image upload failed: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    print("Save tapped");
    if (!_formKey.currentState!.validate()) {
      print("Form invalid");
      return;
    }
    print("Form is valid");
    _formKey.currentState!.save();

    final uid = FirebaseAuth.instance.currentUser!.uid;
    String? imageUrl = _photoUrl;

    try {
      if (_newImage != null) {
        imageUrl = await _uploadImage(_newImage!);
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'firstName': _firstName,
        'lastName': _lastName,
        'username': _username,
        'photoUrl': imageUrl,
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      print("Error saving profile: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save profile")),
      );
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
                                : _photoUrl != null
                                    ? NetworkImage(_photoUrl!) as ImageProvider
                                    : null,
                            backgroundColor: Colors.grey[800],
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
                    TextFormField(
                      initialValue: _firstName,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'First Name', labelStyle: TextStyle(color: Colors.grey)),
                      onSaved: (value) => _firstName = value,
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _lastName,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Last Name', labelStyle: TextStyle(color: Colors.grey)),
                      onSaved: (value) => _lastName = value,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _username,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Username', labelStyle: TextStyle(color: Colors.grey)),
                      onSaved: (value) => _username = value,
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      child: const Text("Save"),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
