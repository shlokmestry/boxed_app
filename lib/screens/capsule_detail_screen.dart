import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:boxed_app/encryption/capsule_encryption.dart';

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
  String? _aesKey;
  int? _backgroundId; // ✅ nullable now
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _showContent = false;

  final List<String> _backgroundImages = [
    'assets/basic_background1.jpg',
    'assets/basic_background2.webp',
    'assets/basic_background3.jpg',
  ];

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
    final key = data['aesKey'];
    final bgId = data['backgroundId']; // now nullable

    if (ts != null) {
      final date = (ts as Timestamp).toDate();
      final now = DateTime.now();
      final unlocked = now.isAfter(date);
      setState(() {
        _unlockDate = date;
        _capsuleTitle = title;
        _capsuleDescription = description;
        _aesKey = key;
        _backgroundId = bgId; // Can be null
        _remaining = date.difference(DateTime.now());
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

  Widget _buildUnlockedView() {
    final String? backgroundAsset = (_backgroundId != null &&
            _backgroundId! >= 0 &&
            _backgroundId! < _backgroundImages.length)
        ? _backgroundImages[_backgroundId!]
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _capsuleTitle ?? 'Capsule',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Only show image if user selected one
          if (backgroundAsset != null)
            Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
            ),

          // Only show overlay if background image exists
          if (backgroundAsset != null)
            Container(
              color: Colors.black.withOpacity(0.4),
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 800),
                    opacity: _showContent ? 1 : 0,
                    child: const Center(
                      child: Icon(Icons.inventory_2, size: 64, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                                shadows: [
                                  Shadow(
                                    blurRadius: 8,
                                    color: Colors.black87,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (_capsuleDescription != null)
                            Text(
                              _capsuleDescription!,
                              style: const TextStyle(
                                color: Colors.white70,
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
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteMemory(Map<String, dynamic> memory) {
    String displayedText = '';

    if (memory.containsKey('encryptedText') && _aesKey != null) {
      try {
        displayedText = CapsuleEncryption.decryptMemory(memory['encryptedText'], _aesKey!);
      } catch (e) {
        displayedText = '[Error decrypting note]';
      }
    } else if (memory.containsKey('text')) {
      displayedText = memory['text'];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          displayedText,
          style: const TextStyle(fontSize: 16, color: Colors.white),
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
