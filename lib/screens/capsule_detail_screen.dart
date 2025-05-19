import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;

  const CapsuleDetailScreen({required this.capsuleId, Key? key}) : super(key: key);

  @override
  State<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

class _CapsuleDetailScreenState extends State<CapsuleDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Capsule Memories"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('capsules')
            .doc(widget.capsuleId)
            .collection('memories')
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No memories yet."));
          }

          final memories = snapshot.data!.docs;

          return ListView.builder(
            itemCount: memories.length,
            itemBuilder: (context, index) {
              final memory = memories[index].data() as Map<String, dynamic>;
              final type = memory['type'];

              if (type == 'note') {
                return _buildNoteMemory(memory);
              } else if (type == 'image') {
                return _buildImageMemory(memory);
              } else {
                return const SizedBox.shrink(); // fallback
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildNoteMemory(Map<String, dynamic> memory) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            memory['text'] ?? '',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildImageMemory(Map<String, dynamic> memory) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          memory['contentUrl'] ?? '',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
