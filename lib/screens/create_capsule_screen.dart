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

      final docRef = await FirebaseFirestore.instance.collection('capsules').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorId': currentUser.uid,
        'unlockDate': Timestamp.fromDate(_selectedDateTime!),
        'memberIds': [currentUser.uid],
        'createdAt': Timestamp.now(),
        'isLocked': true,
        'aesKey': aesKey,
        'backgroundId': _selectedBackground,
      });

      for (final image in _selectedImages) {
        final filename = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance
            .ref()
            .child('capsules/${docRef.id}/$filename.jpg');
        final upload = await ref.putFile(image);
        final url = await upload.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('capsules')
            .doc(docRef.id)
            .collection('memories')
            .add({
          'type': 'image',
          'uploaderId': currentUser.uid,
          'timestamp': Timestamp.now(),
          'contentUrl': url,
        });
      }

      if (_noteController.text.trim().isNotEmpty) {
        final encrypted = CapsuleEncryption.encryptMemory(
            _noteController.text.trim(), aesKey);
        await FirebaseFirestore.instance
            .collection('capsules')
            .doc(docRef.id)
            .collection('memories')
            .add({
          'type': 'note',
          'uploaderId': currentUser.uid,
          'timestamp': Timestamp.now(),
          'encryptedText': encrypted,
        });
      }

      if (_collaboratorEmailController.text.trim().isNotEmpty) {
        final collaboratorQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: _collaboratorEmailController.text.trim())
            .limit(1)
            .get();
        if (collaboratorQuery.docs.isNotEmpty) {
          final uid = collaboratorQuery.docs.first.id;
          await FirebaseFirestore.instance
              .collection('capsules')
              .doc(docRef.id)
              .update({
            'memberIds': FieldValue.arrayUnion([uid]),
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capsule created successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
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
        title: Text(
          "🎁 Create Capsule",
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      backgroundColor: colorScheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(context, "Capsule Name"),
            _buildInput(_nameController, 'Enter a title'),

            const SizedBox(height: 24),
            _sectionLabel(context, "Description"),
            _buildInput(_descriptionController, 'What is this capsule about?', maxLines: 4),

            const SizedBox(height: 24),
            _sectionLabel(context, "Unlock Date"),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                width: double.infinity,
                child: Text(
                  _selectedDateTime == null
                      ? 'Select a future date & time'
                      : 'Opens on: ${_selectedDateTime!.toLocal().toString().replaceFirst(".000", "")}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            _sectionLabel(context, "Capsule Background"),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _backgroundOptions.length + 1,
                itemBuilder: (context, idx) {
                  if (idx == 0) {
                    return _buildBackgroundThumbnail(
                      context,
                      null,
                      isSelected: _selectedBackground == null,
                      child: Icon(Icons.close,
                          size: 36,
                          color: colorScheme.onSurface.withOpacity(0.5)),
                    );
                  } else {
                    return _buildBackgroundThumbnail(
                      context,
                      idx - 1,
                      isSelected: _selectedBackground == (idx - 1),
                      imagePath: _backgroundOptions[idx - 1],
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 24),
            _mediaAndCollaboratorRow(),
            const SizedBox(height: 24),

            _sectionLabel(context, "Write a Note"),
            _buildInput(_noteController, 'Leave a message inside the capsule...',
                maxLines: 4),

            const SizedBox(height: 40),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createCapsule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Create Capsule", style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  /// Section title label styling
  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
    );
  }

  /// Capsule background thumbnail
  Widget _buildBackgroundThumbnail(BuildContext context, int? idx,
      {bool isSelected = false, String? imagePath, Widget? child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _selectedBackground = idx),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imagePath != null
              ? Image.asset(imagePath, fit: BoxFit.cover)
              : Container(
                  alignment: Alignment.center,
                  color: colorScheme.surface,
                  child: child,
                ),
        ),
      ),
    );
  }

  /// Styled input field
  Widget _buildInput(TextEditingController controller, String placeholder,
      {int maxLines = 1}) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: colorScheme.onBackground),
      decoration: InputDecoration(
        hintText: placeholder,
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Media and collaborator sections side-by-side
  Widget _mediaAndCollaboratorRow() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(context, "Upload Photos"),
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
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
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
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Icon(Icons.add_a_photo,
                          color: colorScheme.onSurface.withOpacity(0.5)),
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
              _sectionLabel(context, "Add Collaborator"),
              const SizedBox(height: 8),
              TextField(
                controller: _collaboratorEmailController,
                style: TextStyle(color: colorScheme.onBackground),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
