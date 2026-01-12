import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/user_crypto_state.dart';
import 'package:boxed_app/state/capsule_crypto_state.dart';

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
  int? _backgroundId;

  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _showContent = false;
  bool _isUnlocked = false;
  bool _loading = true;

  List<Map<String, dynamic>> _memories = [];

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

  Future<void> _fetchCapsuleDetails() async {
    // Always start in loading state
    if (mounted) setState(() => _loading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsuleId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capsule not found.')),
        );
        return;
      }

      final data = doc.data();
      if (data == null) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capsule data is empty.')),
        );
        return;
      }

      final capsuleKeys = data['capsuleKeys'];
      if (capsuleKeys is! Map) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('capsuleKeys is missing or invalid.')),
        );
        return;
      }

      final encryptedCapsuleKey = capsuleKeys[currentUser.uid];
      if (encryptedCapsuleKey is! String || encryptedCapsuleKey.isEmpty) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No capsule key found for this user.')),
        );
        return;
      }

      // ✅ Decrypt capsule key (two supported formats)
      // 1) Preferred: decrypt using userMasterKey (AES-GCM SecretBox format)
      // 2) Fallback (MVP): treat encryptedCapsuleKey as raw base64 key bytes
      SecretKey capsuleKey;
      final userMasterKey = UserCryptoState.userMasterKeyOrNull;


      if (userMasterKey != null) {
        try {
          capsuleKey = await BoxedEncryptionService.decryptCapsuleKeyForUser(
            encryptedCapsuleKey: encryptedCapsuleKey,
            userMasterKey: userMasterKey,
          );
        } catch (_) {
          // Fallback to raw base64 key
          final bytes = base64Decode(encryptedCapsuleKey);
          capsuleKey = SecretKey(bytes);
        }
      } else {
        final bytes = base64Decode(encryptedCapsuleKey);
        capsuleKey = SecretKey(bytes);
      }

      CapsuleCryptoState.setCapsuleKey(widget.capsuleId, capsuleKey);

      // Metadata
      final ts = data['unlockDate'];
      final title = data['name'];
      final description = data['description'];
      final bgId = data['backgroundId'];

      if (ts is! Timestamp) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('unlockDate is missing/invalid.')),
        );
        return;
      }

      final date = ts.toDate();
      final now = DateTime.now();
    final unlocked = !now.isBefore(date); 
    final diff = date.difference(now);

      if (!mounted) return;
      setState(() {
        _unlockDate = date;
        _capsuleTitle = (title ?? '').toString();
        _capsuleDescription = (description ?? '').toString();
        _backgroundId = bgId is int ? bgId : null;
_remaining = diff.isNegative ? Duration.zero : diff;
        _isUnlocked = unlocked;
        _loading = false;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        final unlockedNow = now.isAfter(date);
        final newDuration = date.difference(now);

        if (!mounted) return;

        if (unlockedNow) {
          _timer?.cancel();
          setState(() {
            _isUnlocked = true;
            _showContent = true;
            _remaining = Duration.zero;
          });
          _loadAndDecryptMemories();
        } else {
          setState(() {
            _isUnlocked = false;
            _remaining = newDuration;
          });
        }
      });

      if (unlocked) {
        _showContent = true;
        _loadAndDecryptMemories();
      }
    } on TimeoutException {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading timed out. Check connection.')),
      );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load capsule: $e')),
      );
    }
  }

  Future<void> _loadAndDecryptMemories() async {
    try {
      final capsuleKey = CapsuleCryptoState.getCapsuleKey(widget.capsuleId);

      final snapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsuleId)
          .collection('memories')
          .orderBy('createdAt', descending: false)
          .get()
          .timeout(const Duration(seconds: 10));

      final List<Map<String, dynamic>> decryptedMemories = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'text' && data['content'] != null) {
          try {
            final decryptedText = await BoxedEncryptionService.decryptData(
              encryptedText: data['content'],
              capsuleKey: capsuleKey,
            );
            decryptedMemories.add({
              ...data,
              'decryptedContent': decryptedText,
            });
          } catch (_) {
            decryptedMemories.add({
              ...data,
              'decryptedContent': '[Unable to decrypt]',
            });
          }
        }
      }

      if (mounted) setState(() => _memories = decryptedMemories);
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memories load timed out.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load memories: $e')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    CapsuleCryptoState.clearCapsuleKey(widget.capsuleId);
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
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return _isUnlocked ? _buildUnlockedView() : _buildLockedView();
  }

  Widget _buildLockedView() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
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
                child: const Text("Back"),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: true,
                    title: Text(
                      _capsuleTitle ?? 'Capsule',
                      style: textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  if (_capsuleDescription != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _capsuleDescription!,
                      style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Expanded(
                    child: _memories.isEmpty
                        ? Center(
                            child: Text(
                              'No memories yet!',
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _memories.length,
                            itemBuilder: (context, index) {
                              final memory = _memories[index];
                              final content =
                                  (memory['decryptedContent'] ?? '').toString();

                              return Card(
                                color: Colors.white.withOpacity(0.15),
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        content,
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (memory['createdAt'] != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Added: ${DateFormat('MMM dd, yyyy').format((memory['createdAt'] as Timestamp).toDate())}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
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
}
