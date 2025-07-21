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
  final TextEditingController _collaboratorSearchController =
      TextEditingController();

  DateTime? _selectedDateTime;
  bool _isLoading = false;
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  int? _selectedBackground;

  final List<String> _backgroundOptions = [
    'assets/basic_background1.jpg',
    'assets/basic_background2.webp',
    'assets/basic_background3.jpg',
  ];

  final List<Map<String, dynamic>> _collaborators = [];
  List<Map<String, dynamic>> _userSearchResults = [];

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _userSearchResults = []);
      return;
    }

    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(10)
        .get();

    setState(() {
      _userSearchResults = result.docs.map((doc) {
        return {
          'userId': doc.id,
          'username': doc['username'] ?? '',
          'email': doc['email'] ?? '',
        };
      }).toList();
    });
  }

  void _addCollaborator(Map<String, dynamic> user) {
    final alreadyAdded =
        _collaborators.any((c) => c['userId'] == user['userId']);
    if (!alreadyAdded) {
      setState(() {
        _collaborators.add(user);
        _collaboratorSearchController.clear();
        _userSearchResults.clear();
      });
    }
  }

  void _removeCollaborator(String userId) {
    setState(() {
      _collaborators.removeWhere((c) => c['userId'] == userId);
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 12, minute: 0),
      );
      if (pickedTime != null) {
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
    }
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
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
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_nameController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final aesKey = CapsuleEncryption.generateAESKey();

      final capsuleRef = await FirebaseFirestore.instance
          .collection('capsules')
          .add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorId': currentUser.uid,
        'unlockDate': Timestamp.fromDate(_selectedDateTime!),
        'memberIds': [currentUser.uid, ..._collaborators.map((c) => c['userId'])],
        'createdAt': Timestamp.now(),
        'isLocked': true,
        'aesKey': aesKey,
        'backgroundId': _selectedBackground,
      });

      // Upload images
      for (final image in _selectedImages) {
        final filename = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance
            .ref()
            .child('capsules/${capsuleRef.id}/$filename.jpg');
        final upload = await ref.putFile(image);
        final url = await upload.ref.getDownloadURL();

        await capsuleRef.collection('memories').add({
          'type': 'image',
          'uploaderId': currentUser.uid,
          'timestamp': Timestamp.now(),
          'contentUrl': url,
        });
      }

      // Add note
      if (_noteController.text.trim().isNotEmpty) {
        final encrypted = CapsuleEncryption.encryptMemory(
          _noteController.text.trim(),
          aesKey,
        );
        await capsuleRef.collection('memories').add({
          'type': 'note',
          'uploaderId': currentUser.uid,
          'timestamp': Timestamp.now(),
          'encryptedText': encrypted,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capsule created!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("🎁 Create Capsule", style: textTheme.titleLarge),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(context, "Capsule Name"),
            _buildInput(_nameController, 'Enter a title'),
            const SizedBox(height: 16),

            _sectionLabel(context, "Description"),
            _buildInput(_descriptionController, 'What’s this about?',
                maxLines: 4),
            const SizedBox(height: 16),

            _sectionLabel(context, "Unlock Date"),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.surface,
                ),
                child: Text(
                  _selectedDateTime == null
                      ? 'Pick unlock date'
                      : 'Opens on: $_selectedDateTime',
                ),
              ),
            ),
            const SizedBox(height: 16),

            _sectionLabel(context, "Background"),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _backgroundOptions.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _selectedBackground = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedBackground == i
                            ? colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(_backgroundOptions[i],
                          width: 80, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            _sectionLabel(context, "Add Collaborators"),
            TextField(
              controller: _collaboratorSearchController,
              onChanged: _searchUsers,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
            const SizedBox(height: 8),
            if (_userSearchResults.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: _userSearchResults.map((user) {
                    return ListTile(
                      title: Text(user['username'] ?? ''),
                      subtitle: Text(user['email'] ?? ''),
                      onTap: () => _addCollaborator(user),
                    );
                  }).toList(),
                ),
              ),
            _buildCollaboratorChips(),

            const SizedBox(height: 24),
            _sectionLabel(context, "Write a Note"),
            _buildInput(_noteController, 'Leave something inside...',
                maxLines: 3),

            const SizedBox(height: 24),
            _sectionLabel(context, "Add Images"),
            Wrap(
              spacing: 8,
              children: [
                ..._selectedImages.map((image) => Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(image,
                              width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _removeImage(image),
                        ),
                      ],
                    )),
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: const Icon(Icons.add_a_photo),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createCapsule,
                      child: const Text("Create Capsule",
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollaboratorChips() {
    return Wrap(
      spacing: 8,
      children: _collaborators.map((c) {
        return Chip(
          label: Text(c['username'] ?? ''),
          onDeleted: () => _removeCollaborator(c['userId'] ?? ''),
        );
      }).toList(),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}
