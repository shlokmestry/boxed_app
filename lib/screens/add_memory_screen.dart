import 'package:flutter/material.dart';
import 'package:boxed_app/widgets/buttons.dart'; // Adjust path if needed

class AddMemoryScreen extends StatefulWidget {
  final String capsuleId;

  const AddMemoryScreen({required this.capsuleId, Key? key}) : super(key: key);

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  String memoryType = 'note';
  final TextEditingController _noteController = TextEditingController();
  String? _selectedImagePath;

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
             
              onPressed: () {
                // Next step: implement upload logic
              }, child: null,
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
      children: const [
        Text(
          "Image Picker (coming next step)",
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 20),
        Placeholder(fallbackHeight: 150),
      ],
    );
  }
}
