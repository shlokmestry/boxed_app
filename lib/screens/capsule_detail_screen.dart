import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  int? _backgroundId;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _showContent = false;
  bool _isUnlocked = false;
  bool _loading = true;

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
    final bgId = data['backgroundId'];

    if (ts != null) {
      final date = (ts as Timestamp).toDate();
      final now = DateTime.now();
      final unlocked = now.isAfter(date);

      setState(() {
        _unlockDate = date;
        _capsuleTitle = title;
        _capsuleDescription = description;
        _aesKey = key;
        _backgroundId = bgId;
        _remaining = date.difference(now);
        _isUnlocked = unlocked;
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '$days days $hours hrs $minutes min $seconds sec';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return _isUnlocked ? _buildUnlockedView() : _buildLockedView();
  }

  Widget _buildLockedView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                "You're a bit early!",
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (_capsuleTitle != null)
                Text(
                  _capsuleTitle!,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 10),
              if (_unlockDate != null)
                Text(
                  'Unlocks on: ${DateFormat.yMMMd().add_jm().format(_unlockDate!)}',
                  style: TextStyle(
                      color: colorScheme.onBackground.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 18),
              Text(
                '⏳ ${_formatDuration(_remaining)}',
                style: TextStyle(color: colorScheme.primary, fontSize: 18),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final String? backgroundAsset = (_backgroundId != null &&
            _backgroundId! >= 0 &&
            _backgroundId! < _backgroundImages.length)
        ? _backgroundImages[_backgroundId!]
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: backgroundAsset != null
                ? Image.asset(backgroundAsset, fit: BoxFit.cover)
                : Container(color: colorScheme.background),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          title: Text(
                            _capsuleTitle ?? 'Capsule',
                            style: textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          centerTitle: true,
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 800),
                          opacity: _showContent ? 1 : 0,
                          child: Center(
                            child: Column(
                              children: const [
                                Icon(Icons.inventory_2,
                                    size: 64, color: Colors.white),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_capsuleTitle != null)
                                  Text(
                                    _capsuleTitle!,
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                if (_capsuleDescription != null)
                                  Text(
                                    _capsuleDescription!,
                                    style: textTheme.bodyMedium
                                        ?.copyWith(color: Colors.white70),
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
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (!snapshot.hasData ||
                                        snapshot.data!.docs.isEmpty) {
                                      return Text(
                                        "No memories yet.",
                                        style: textTheme.bodyMedium
                                            ?.copyWith(color: Colors.white60),
                                      );
                                    }

                                    final memories = snapshot.data!.docs;
                                    return Column(
                                      children: memories.map((doc) {
                                        final memory = doc.data()
                                            as Map<String, dynamic>;
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
                                    style: textTheme.bodySmall
                                        ?.copyWith(color: Colors.white70),
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
          ),
        ],
      ),
    );
  }

  Widget _buildNoteMemory(Map<String, dynamic> memory) {
    final String? encryptedText = memory['encryptedText'];
    final String? plainText = memory['text'];
    String displayedText = '';

    print("AES KEY: $_aesKey");
    print("Memory Map: $memory");

    if ((encryptedText?.trim().isNotEmpty ?? false) &&
        (_aesKey?.trim().isNotEmpty ?? false)) {
      try {
        final decrypted = CapsuleEncryption.decryptMemory(
            encryptedText!.trim(), _aesKey!.trim());

        if (_isReadable(decrypted)) {
          displayedText = decrypted;
        } else if ((plainText?.trim().isNotEmpty ?? false)) {
          displayedText = plainText!;
        } else {
          displayedText = '[Note could not be decrypted]';
        }
      } catch (e) {
        print("Decryption failed: $e");
        displayedText = (plainText?.trim().isNotEmpty ?? false)
            ? plainText!
            : '[Note could not be decrypted]';
      }
    } else if ((plainText?.trim().isNotEmpty ?? false)) {
      displayedText = plainText!;
    } else {
      displayedText = '[No note content found]';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Text(
          displayedText,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }

  bool _isReadable(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final cleaned = text.trim();
    return cleaned.codeUnits
        .every((unit) => unit >= 32 && unit <= 126 || unit == 10);
  }

  Widget _buildImageMemory(Map<String, dynamic> memory) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          memory['contentUrl'] ?? '',
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
