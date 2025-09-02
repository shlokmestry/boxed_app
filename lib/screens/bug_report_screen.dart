import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _submitBugReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'Anonymous';
    final timestamp = DateTime.now();

    try {
      await FirebaseFirestore.instance.collection('bug_reports').add({
        'userId': uid,
        'description': _descriptionController.text.trim(),
        'stepsToReproduce': _stepsController.text.trim(),
        'createdAt': timestamp.toUtc(),
        'appVersion': '1.0.0', // Adjust dynamically if possible
        'deviceInfo': '', // Optionally add device info here
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bug report submitted! Thank you.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit bug report: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Bug'),
        backgroundColor: colorScheme.background,
        iconTheme: IconThemeData(color: colorScheme.primary),
        elevation: 0,
      ),
      backgroundColor: colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Describe the issue you encountered:',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Bug description *',
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Optional: Steps to reproduce or expected/actual behavior:',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _stepsController,
                maxLines: 5,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: 'Steps to reproduce',
                  filled: true,
                  fillColor: colorScheme.surface,
                ),
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitBugReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: colorScheme.primary,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Bug Report', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
