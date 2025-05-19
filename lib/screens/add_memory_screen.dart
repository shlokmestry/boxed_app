import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMemoryScreen extends StatefulWidget {
  final String capsuleId;

  const AddMemoryScreen({required this.capsuleId, Key? key}) : super(key: key);

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  String memoryType = 'note';
  final TextEditingController _noteController = TextEditingController();
  File? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _uploadMemory() async {
    if (memoryType == 'image' && _selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to upload a memory')),
        );
        return;
      }

      final uid = user.uid;
      final capsuleId = widget.capsuleId;
      final timestamp = Timestamp.now();
      String? downloadUrl;

      if (memoryType == 'image') {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('capsules/$capsuleId/memories/$fileName.jpg');

        final uploadTask = await storageRef.putFile(_selectedImageFile!);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

      final memoryData = {
        'type': memoryType,
        'uploaderId': uid,
        'timestamp': timestamp,
        if (memoryType == 'image') 'contentUrl': downloadUrl,
        if (memoryType == 'note') 'text': _noteController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('capsules')
          .doc(capsuleId)
          .collection('memories')
          .add(memoryData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory uploaded successfully')),
      );

      setState(() {
        _noteController.clear();
        _selectedImageFile = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add Memory'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Choose Memory Type",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => memoryType = 'note'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: memoryType == 'note'
                          ? Colors.blue.shade100.withOpacity(0.2)
                          : Colors.transparent,
                      side: BorderSide(
                        color: memoryType == 'note'
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Text Note",
                      style: TextStyle(
                        color: memoryType == 'note'
                            ? Colors.blue
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => memoryType = 'image'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: memoryType == 'image'
                          ? Colors.blue.shade100.withOpacity(0.2)
                          : Colors.transparent,
                      side: BorderSide(
                        color: memoryType == 'image'
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Image",
                      style: TextStyle(
                        color: memoryType == 'image'
                            ? Colors.blue
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (memoryType == 'note') _buildNoteInput(context),
            if (memoryType == 'image') _buildImagePickerPlaceholder(),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _uploadMemory,
              child: const Text('Upload Memory'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Write your note",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Your memory...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[850],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pick an Image",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: _selectedImageFile == null
                ? const Center(
                    child: Text(
                      "Tap to select image",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImageFile!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
