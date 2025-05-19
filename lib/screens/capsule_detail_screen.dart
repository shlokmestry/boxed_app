import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;
  final bool isUnlocked;

  const CapsuleDetailScreen({
    required this.capsuleId,
    required this.isUnlocked,
    Key? key,
  }) : super(key: key);

  @override
  State<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

class _CapsuleDetailScreenState extends State<CapsuleDetailScreen> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isUnlocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Capsule Locked"),
          centerTitle: true,
          backgroundColor: Colors.black,
        ),
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "This capsule is still locked.",
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                "Come back later to view the memories!",
                style: TextStyle(color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Capsule Memories"),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
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
            return const Center(
              child: Text(
                "No memories yet.",
                style: TextStyle(color: Colors.white54),
              ),
            );
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
        color: Colors.grey[850],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            memory['text'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 16),
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
