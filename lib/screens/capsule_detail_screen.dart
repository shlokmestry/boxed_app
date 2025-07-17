import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;

  const CapsuleDetailScreen({
    required this.capsuleId,
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
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }
    return _isUnlocked ? _buildUnlockedView(colorScheme) : _buildLockedView(colorScheme);
  }

  Widget _buildLockedView(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                "You're a bit early!",
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (_capsuleTitle != null)
                Text(
                  _capsuleTitle!,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
              const SizedBox(height: 10),
              if (_unlockDate != null)
                Text(
                  'Unlocks on: ${DateFormat.yMMMd().add_jm().format(_unlockDate!)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.5),
                  ),
                ),
              const SizedBox(height: 20),
              if (_unlockDate != null)
                Text(
                  '⏳ ${_formatDuration(_remaining)}',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Back",
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedView(ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          _capsuleTitle ?? 'Capsule',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
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
                  children: [
                    Icon(Icons.inventory_2, size: 64, color: colorScheme.primary),
                    const SizedBox(height: 12),
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
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onBackground,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_capsuleDescription != null)
                      Text(
                        _capsuleDescription!,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.7),
                          fontSize: 16,
                        ),
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
                          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              "No memories yet.",
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onBackground.withOpacity(0.65),
                              ),
                            ),
                          );
                        }

                        final memories = snapshot.data!.docs;

                        return Column(
                          children: memories.map((doc) {
                            final memory = doc.data() as Map<String, dynamic>;
                            final type = memory['type'];

                            if (type == 'note') {
                              return _buildNoteMemory(memory, colorScheme, textTheme);
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
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.6),
                          fontSize: 14,
                        ),
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

  Widget _buildNoteMemory(Map<String, dynamic> memory, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            memory['text'] ?? '',
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
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
