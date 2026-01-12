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
  bool _isUnlocked = false;
  bool _loading = true;

  // ✅ Text memories
  List<Map<String, dynamic>> _textMemories = [];
  bool _textLoading = false;

  final List<String> _backgroundImages = const [
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

      // ─────────────────────────────────────────────
      // 1) Read capsule key for this user
      // ─────────────────────────────────────────────
      final capsuleKeys = data['capsuleKeys'];
      if (capsuleKeys is! Map) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('capsuleKeys missing/invalid.')),
        );
        return;
      }

      final storedKeyValue = capsuleKeys[currentUser.uid];
      if (storedKeyValue is! String || storedKeyValue.isEmpty) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No capsule key for this user.')),
        );
        return;
      }

      // ─────────────────────────────────────────────
      // 2) Decrypt capsule key
      //    - New capsules: encrypted SecretBox string (decrypt with master key)
      //    - Old capsules: raw base64 key bytes (fallback)
      // ─────────────────────────────────────────────
      SecretKey capsuleKey;
      final userMasterKey = UserCryptoState.userMasterKeyOrNull;

      if (userMasterKey != null) {
        try {
          capsuleKey = await BoxedEncryptionService.decryptCapsuleKeyForUser(
            encryptedCapsuleKey: storedKeyValue,
            userMasterKey: userMasterKey,
          );
        } catch (_) {
          capsuleKey = SecretKey(base64Decode(storedKeyValue));
        }
      } else {
        try {
          capsuleKey = SecretKey(base64Decode(storedKeyValue));
        } catch (_) {
          if (mounted) setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Master key missing. Please log in again.')),
          );
          return;
        }
      }

      CapsuleCryptoState.setCapsuleKey(widget.capsuleId, capsuleKey);

      // ─────────────────────────────────────────────
      // 3) Metadata + countdown
      // ─────────────────────────────────────────────
      final ts = data['unlockDate'];
      if (ts is! Timestamp) {
        if (mounted) setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('unlockDate missing/invalid.')),
        );
        return;
      }

      final date = ts.toDate();
      final now = DateTime.now();
      final unlocked = !now.isBefore(date); // now >= date is unlocked

      Duration diff = date.difference(now);
      if (diff.isNegative) diff = Duration.zero;

      if (!mounted) return;
      setState(() {
        _unlockDate = date;
        _capsuleTitle = (data['name'] ?? '').toString();
        _capsuleDescription = (data['description'] ?? '').toString();
        _backgroundId = data['backgroundId'] is int ? data['backgroundId'] as int : null;
        _remaining = diff;
        _isUnlocked = unlocked;
        _loading = false;
      });

      // ✅ Load notes immediately if already unlocked
      if (unlocked) {
        _loadAndDecryptTextMemories();
      }

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        final unlockedNow = !now.isBefore(date);

        Duration newDiff = date.difference(now);
        if (newDiff.isNegative) newDiff = Duration.zero;

        if (!mounted) return;

        if (unlockedNow) {
          _timer?.cancel();
          setState(() {
            _isUnlocked = true;
            _remaining = Duration.zero;
          });

          // ✅ Load notes when it flips to unlocked
          _loadAndDecryptTextMemories();
        } else {
          setState(() {
            _isUnlocked = false;
            _remaining = newDiff;
          });
        }
      });
    } on TimeoutException {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading timed out.')),
      );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load capsule: $e')),
      );
    }
  }

  Future<void> _loadAndDecryptTextMemories() async {
    if (_textLoading) return;
    if (!mounted) return;

    setState(() => _textLoading = true);

    try {
      final capsuleKey = CapsuleCryptoState.getCapsuleKey(widget.capsuleId);

      final snapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsuleId)
          .collection('memories')
          .where('type', isEqualTo: 'text')
          .orderBy('createdAt', descending: false)
          .get();

      final List<Map<String, dynamic>> out = [];

      for (final d in snapshot.docs) {
        final data = d.data();
        final encrypted = (data['content'] ?? '').toString();
        if (encrypted.isEmpty) continue;

        try {
          final clear = await BoxedEncryptionService.decryptData(
            encryptedText: encrypted,
            capsuleKey: capsuleKey,
          );
          out.add({...data, 'decryptedContent': clear});
        } catch (_) {
          out.add({...data, 'decryptedContent': '[Unable to decrypt]'});
        }
      }

      if (mounted) setState(() => _textMemories = out);
    } finally {
      if (mounted) setState(() => _textLoading = false);
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
              if (_capsuleTitle != null && _capsuleTitle!.trim().isNotEmpty)
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
                  style: TextStyle(color: colorScheme.onBackground.withOpacity(0.6)),
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
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                  if (_capsuleDescription != null &&
                      _capsuleDescription!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _capsuleDescription!,
                      style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ✅ Images (fixed height)
                  SizedBox(
                    height: 170,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('capsules')
                          .doc(widget.capsuleId)
                          .collection('memories')
                          .where('type', isEqualTo: 'image')
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No images yet.',
                              style: textTheme.titleMedium?.copyWith(color: Colors.white70),
                            ),
                          );
                        }

                        final memories = snapshot.data!.docs;

                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: memories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final memory =
                                memories[index].data() as Map<String, dynamic>;
                            return _buildImageMemory(memory);
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Notes',
                      style: textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Notes list
                  Expanded(
                    child: _textLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _textMemories.isEmpty
                            ? Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  'No notes yet.',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _textMemories.length,
                                itemBuilder: (context, i) {
                                  final m = _textMemories[i];
                                  final text =
                                      (m['decryptedContent'] ?? '').toString();

                                  return Card(
                                    color: Colors.white.withOpacity(0.12),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        text,
                                        style: textTheme.bodyMedium
                                            ?.copyWith(color: Colors.white),
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

  Widget _buildImageMemory(Map<String, dynamic> memory) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        (memory['content'] ?? '').toString(),
        width: 150,
        height: 150,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
