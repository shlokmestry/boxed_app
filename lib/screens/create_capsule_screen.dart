import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:boxed_app/encryption/capsule_encryption.dart';

class CreateCapsuleScreen extends StatefulWidget {
  const CreateCapsuleScreen({super.key});

  @override
  State<CreateCapsuleScreen> createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _collaboratorEmailController = TextEditingController();

  DateTime? _selectedDate;
  bool _isLoading = false;
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // Use `null` for "No Background"
  int? _selectedBackground;

  final List<String> _backgroundOptions = [
    'assets/basic_background1.jpg',
    'assets/basic_background2.webp',
    'assets/basic_background3.jpg',
  ];

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  void _removeImage(File file) {
    setState(() {
      _selectedImages.remove(file);
    });
  }

  Future<void> _createCapsule() async {
    if (_nameController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final aesKey = CapsuleEncryption.generateAESKey();

      final docRef = await FirebaseFirestore.instance.collection('capsules').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorId': user.uid,
        'unlockDate': Timestamp.fromDate(_selectedDate!),
        'memberIds': [user.uid],
        'createdAt': Timestamp.now(),
        'isLocked': true,
        'aesKey': aesKey,
        'backgroundId': _selectedBackground, // ← Will be null if not chosen
      });

      for (final image in _selectedImages) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('capsules/${docRef.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadTask = await storageRef.putFile(image);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('capsules')
            .doc(docRef.id)
            .collection('memories')
            .add({
          'type': 'image',
          'uploaderId': user.uid,
          'timestamp': Timestamp.now(),
          'contentUrl': downloadUrl,
        });
      }

      if (_noteController.text.trim().isNotEmpty) {
        final encryptedNote = CapsuleEncryption.encryptMemory(
          _noteController.text.trim(),
          aesKey,
        );

        await FirebaseFirestore.instance
            .collection('capsules')
            .doc(docRef.id)
            .collection('memories')
            .add({
          'type': 'note',
          'uploaderId': user.uid,
          'timestamp': Timestamp.now(),
          'encryptedText': encryptedNote,
        });
      }

      final collaboratorEmail = _collaboratorEmailController.text.trim();
      if (collaboratorEmail.isNotEmpty) {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: collaboratorEmail)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final collaboratorId = query.docs.first.id;
          await FirebaseFirestore.instance
              .collection('capsules')
              .doc(docRef.id)
              .update({
            'memberIds': FieldValue.arrayUnion([collaboratorId]),
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capsule created successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating capsule: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Create Capsule"),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Capsule Name", style: _labelStyle(context)),
            const SizedBox(height: 8),
            _buildInput(_nameController, 'Enter a title'),
            const SizedBox(height: 24),

            Text("Description", style: _labelStyle(context)),
            const SizedBox(height: 8),
            _buildInput(_descriptionController, 'What is this capsule about?', maxLines: 4),
            const SizedBox(height: 24),

            Text("Unlock Date", style: _labelStyle(context)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Select a future date'
                      : 'Opens on: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text("Select Capsule Background", style: _labelStyle(context)),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _backgroundOptions.length + 1, // +1 for "No background"
                itemBuilder: (context, idx) {
                  if (idx == 0) {
                    // "No background" option
                    return GestureDetector(
                      onTap: () => setState(() => _selectedBackground = null),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedBackground == null
                                ? Colors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.black,
                        ),
                        width: 90,
                        height: 90,
                        child: const Center(
                          child: Icon(Icons.close, color: Colors.white54, size: 36),
                        ),
                      ),
                    );
                  } else {
                    return GestureDetector(
                      onTap: () => setState(() => _selectedBackground = idx - 1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedBackground == (idx - 1)
                                ? Colors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            _backgroundOptions[idx - 1],
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 24),
            _buildMediaAndCollaboratorRow(),
            const SizedBox(height: 24),

            Text("Write a Note", style: _labelStyle(context)),
            const SizedBox(height: 8),
            _buildInput(_noteController, 'Share a memory, story, or message...', maxLines: 5),
            const SizedBox(height: 40),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createCapsule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Create Capsule', style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  TextStyle _labelStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );
  }

  Widget _buildInput(TextEditingController controller, String placeholder,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[850],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildMediaAndCollaboratorRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Upload Photos", style: _labelStyle(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._selectedImages.map((file) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(file),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )),
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: const Icon(Icons.add_a_photo, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Add Collaborator", style: _labelStyle(context)),
              const SizedBox(height: 8),
              TextField(
                controller: _collaboratorEmailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[850],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
