import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class CollaboratorEditCapsuleScreen extends StatefulWidget {
  final String capsuleId;

  const CollaboratorEditCapsuleScreen({super.key, required this.capsuleId});

  @override
  State<CollaboratorEditCapsuleScreen> createState() =>
      _CollaboratorEditCapsuleScreenState();
}

class _CollaboratorEditCapsuleScreenState
    extends State<CollaboratorEditCapsuleScreen> {
  final _noteController = TextEditingController();
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _isSubmitting = false;

  String? capsuleName;
  DateTime? unlockDate;

  @override
  void initState() {
    super.initState();
    _loadCapsule();
  }

  Future<void> _loadCapsule() async {
    final doc = await FirebaseFirestore.instance
        .collection('capsules')
        .doc(widget.capsuleId)
        .get();
    final data = doc.data();

    if (data == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      capsuleName = data['name'];
      unlockDate = (data['unlockDate'] as Timestamp).toDate();
      _isLoading = false;
    });
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _removeImage(File file) async {
    setState(() {
      _selectedImages.remove(file);
    });
  }

  Future<void> _submitCapsule() async {
    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser!;
    final capsuleRef =
        FirebaseFirestore.instance.collection('capsules').doc(widget.capsuleId);

    // Upload images
    for (final image in _selectedImages) {
      final filename = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child('capsules/${widget.capsuleId}/$filename.jpg');
      final upload = await ref.putFile(image);
      final url = await upload.ref.getDownloadURL();

      await capsuleRef.collection('memories').add({
        'type': 'image',
        'createdBy': user.uid,
        'createdAt': Timestamp.now(),
        'contentUrl': url,
      });
    }

    // Upload note
    final note = _noteController.text.trim();
    if (note.isNotEmpty) {
      await capsuleRef.collection('memories').add({
        'type': 'text',
        'createdBy': user.uid,
        'createdAt': Timestamp.now(),
        'content': note,
      });
    }

    // Mark collaborator as accepted & activate capsule
    final doc = await capsuleRef.get();
    final data = doc.data();
    final currentUserId = user.uid;

    final updatedCollaborators = (data!['collaborators'] as List)
        .map((c) {
          if (c['uid'] == currentUserId) {
            c['accepted'] = true;
          }
          return c;
        })
        .toList();

    final allAccepted =
        updatedCollaborators.every((c) => c['accepted'] == true);

    await capsuleRef.update({
      'collaborators': updatedCollaborators,
      'status': allAccepted ? 'locked' : 'pending',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Capsule submitted! 🎉")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Capsule", style: textTheme.titleMedium),
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.primary,
        elevation: 0,
      ),
      backgroundColor: colorScheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capsuleName ?? "Untitled Capsule",
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    if (unlockDate != null)
                      Text(
                        "Unlocks on: ${DateFormat('MMM d, yyyy – hh:mm a').format(unlockDate!)}",
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                    const SizedBox(height: 24),

                    Text("Write a Note", style: textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Write something...",
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text("Add Photos", style: textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
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
                                      decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
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
                              border:
                                  Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Icon(Icons.add_a_photo,
                                color: colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed:
                            _isSubmitting ? null : () => _submitCapsule(),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text("Finish Capsule"),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
