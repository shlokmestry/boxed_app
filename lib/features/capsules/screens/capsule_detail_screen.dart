import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boxed_app/services/boxed_encryption_service.dart';
import 'package:boxed_app/state/capsule_crypto_state.dart';
import 'package:boxed_app/state/user_crypto_state.dart';

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

  // Notes (text memories)
  bool _textLoading = false;
  List<Map<String, dynamic>> _textMemories = [];
  String? _error;

  final List<String> _backgroundImages = const [
    'assets/basic/background1.jpg',
    'assets/basic/background2.webp',
    'assets/basic/background3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCapsuleDetails();
  }

  Future<void> _fetchCapsuleDetails() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'User not signed in.';
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsuleId)
          .get()
          .timeout(const Duration(seconds: 10));

      final data = doc.data();
      if (data == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Capsule not found.';
        });
        return;
      }

      // 1) Get encrypted capsule key for this user
      final capsuleKeys = data['capsuleKeys'];
      if (capsuleKeys is! Map) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'capsuleKeys missing/invalid.';
        });
        return;
      }

      final encryptedCapsuleKey = capsuleKeys[currentUser.uid];
      if (encryptedCapsuleKey is! String || encryptedCapsuleKey.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No capsule key found for this user.';
        });
        return;
      }

      // 2) Decrypt capsule key using persisted master key
      final userMasterKey = UserCryptoState.userMasterKeyOrNull;
      if (userMasterKey == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Master key missing. Please log in again.';
        });
        return;
      }

      final capsuleKey = await BoxedEncryptionService.decryptCapsuleKeyForUser(
        encryptedCapsuleKey: encryptedCapsuleKey,
        userMasterKey: userMasterKey,
      );

      CapsuleCryptoState.setCapsuleKey(widget.capsuleId, capsuleKey);

      // 3) Metadata
      final ts = data['unlockDate'];
      if (ts is! Timestamp) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'unlockDate missing/invalid.';
        });
        return;
      }

      final unlockDate = ts.toDate();
      final now = DateTime.now();
      final unlocked = !now.isBefore(unlockDate);

      Duration diff = unlockDate.difference(now);
      if (diff.isNegative) diff = Duration.zero;

      if (!mounted) return;
      setState(() {
        _unlockDate = unlockDate;
        _capsuleTitle = (data['name'] ?? '').toString();
        _capsuleDescription = (data['description'] ?? '').toString();
        _backgroundId =
            data['backgroundId'] is int ? data['backgroundId'] as int : null;
        _remaining = diff;
        _isUnlocked = unlocked;
        _loading = false;
      });

      // Load notes immediately if already unlocked
      if (unlocked) {
        await _loadAndDecryptTextMemories();
      }

      // Countdown timer
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final now = DateTime.now();
        final unlockedNow = !now.isBefore(unlockDate);

        Duration newDiff = unlockDate.difference(now);
        if (newDiff.isNegative) newDiff = Duration.zero;

        if (!mounted) return;

        if (unlockedNow && !_isUnlocked) {
          // Just flipped to unlocked
          setState(() {
            _isUnlocked = true;
            _remaining = Duration.zero;
          });
          await _loadAndDecryptTextMemories();
        } else if (!unlockedNow) {
          setState(() {
            _isUnlocked = false;
            _remaining = newDiff;
          });
        } else {
          // already unlocked
          setState(() => _remaining = Duration.zero);
        }
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Loading timed out.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load capsule: $e';
      });
    }
  }

  Future<void> _loadAndDecryptTextMemories() async {
    if (_textLoading) return;

    if (!mounted) return;
    setState(() {
      _textLoading = true;
      _error = null;
    });

    try {
      final capsuleKey = CapsuleCryptoState.getCapsuleKey(widget.capsuleId);

      final snapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsuleId)
          .collection('memories')
          .where('type', isEqualTo: 'text')
          .orderBy('createdAt', descending: false)
          .get()
          .timeout(const Duration(seconds: 10));

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

      if (!mounted) return;
      setState(() => _textMemories = out);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _error = 'Loading notes timed out.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load notes: $e');
    } finally {
      if (!mounted) return;
      setState(() => _textLoading = false);
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

    if (_error != null) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          title: const Text('Capsule'),
          backgroundColor: colorScheme.background,
          foregroundColor: colorScheme.primary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ),
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
              if ((_capsuleTitle ?? '').trim().isNotEmpty)
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
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

    final String? backgroundAsset =
        (_backgroundId != null &&
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
                  if ((_capsuleDescription ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _capsuleDescription!,
                      style:
                          textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_unlockDate != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Unlocked on: ${DateFormat.yMMMd().add_jm().format(_unlockDate!)}',
                        style: textTheme.bodySmall?.copyWith(color: Colors.white70),
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
}
