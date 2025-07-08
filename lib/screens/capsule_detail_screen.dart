import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;

  const CapsuleDetailScreen({
    required this.capsuleId,
    Key? key, required ,
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
  bool _showContent = false;
  bool _isUnlocked = false;
  bool _loading = true;

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
      final now = DateTime.now();
      final unlocked = now.isAfter(date);
      setState(() {
        _unlockDate = date;
        _capsuleTitle = title;
        _capsuleDescription = description;
        _isUnlocked = unlocked;
        _remaining = date.difference(now);
        _loading = false;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        final unlockedNow = now.isAfter(date);
        final newDuration = date.difference(now);
        if (unlockedNow) {
          _timer?.cancel();
          setState(() {
            _isUnlocked = true;
            _showContent = true;
            _remaining = Duration.zero;
          });
        } else {
          setState(() {
            _isUnlocked = false;
            _remaining = newDuration;
          });
        }
      });

      // Show content animation if unlocked
      if (unlocked) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _showContent = true;
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
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _isUnlocked ? _buildUnlockedView() : _buildLockedView();
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_capsuleTitle ?? 'Capsule'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _showContent ? 1 : 0,
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.inventory_2, size: 64, color: Colors.white),
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _showContent ? 1 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 600),
                scale: _showContent ? 1.0 : 0.95,
                curve: Curves.easeOutBack,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_capsuleTitle != null)
                      Text(
                        _capsuleTitle!,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_capsuleDescription != null)
                      Text(
                        _capsuleDescription!,
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    const SizedBox(height: 20),
                    StreamBuilder<QuerySnapshot>(
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

                        return Column(
                          children: memories.map((doc) {
                            final memory = doc.data() as Map<String, dynamic>;
                            final type = memory['type'];

                            if (type == 'note') {
                              return _buildNoteMemory(memory);
                            } else if (type == 'image') {
                              return _buildImageMemory(memory);
                            } else {
                              return const SizedBox.shrink();
                            }
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_unlockDate != null)
                      Text(
                        'Unlocked on: ${DateFormat.yMMMd().add_jm().format(_unlockDate!)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteMemory(Map<String, dynamic> memory) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
      padding: const EdgeInsets.only(bottom: 16),
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
