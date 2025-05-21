import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
  DateTime? _unlockDate;
  String? _capsuleTitle;
  String? _capsuleDescription;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchCapsuleDetails();
  }

  void _fetchCapsuleDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('capsules')
        .doc(widget.capsuleId)
        .get();

    final data = doc.data();
    if (data == null) return;

    final ts = data['unlockDate'];
    final title = data['name'];
    final description = data['description'];

    if (ts != null) {
      final date = (ts as Timestamp).toDate();
      setState(() {
        _unlockDate = date;
        _capsuleTitle = title;
        _capsuleDescription = description;
        _remaining = date.difference(DateTime.now());
      });

      if (!widget.isUnlocked) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          final newDuration = date.difference(DateTime.now());
          if (newDuration.isNegative) {
            _timer?.cancel();
            setState(() {
              _remaining = Duration.zero;
            });
          } else {
            setState(() {
              _remaining = newDuration;
            });
          }
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '$days days $hours hrs $minutes min $seconds sec';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isUnlocked) {
      return _buildUnlockedView();
    } else {
      return _buildLockedView();
    }
  }

  Widget _buildLockedView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                "You're a bit early!",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              if (_capsuleTitle != null)
                Text(
                  _capsuleTitle!,
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
              const SizedBox(height: 10),
              if (_unlockDate != null)
                Text(
                  'Unlocks on: ${DateFormat.yMMMd().add_jm().format(_unlockDate!)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 20),
              if (_unlockDate != null)
                Text(
                  '⏳ ${_formatDuration(_remaining)}',
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 18),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Back", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedView() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_capsuleTitle ?? "Capsule"),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_capsuleDescription != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                _capsuleDescription!,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          if (_unlockDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(
                'Unlocked on: ${DateFormat.yMMMd().add_jm().format(_unlockDate!)}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
              ),
            ),
          const Divider(color: Colors.grey),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                    child: Text("No memories yet.",
                        style: TextStyle(color: Colors.white70)),
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
                      return const SizedBox.shrink();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          // TODO: Navigate to AddMemoryScreen if needed
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteMemory(Map<String, dynamic> memory) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Colors.grey[900],
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            memory['text'] ?? '',
            style: const TextStyle(fontSize: 16, color: Colors.white),
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
