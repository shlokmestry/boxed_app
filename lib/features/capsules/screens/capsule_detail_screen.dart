import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:boxed_app/core/services/boxed_encryption_service.dart';
import 'package:boxed_app/core/state/capsule_crypto_state.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;

  /// Update this to your real feed route.
  /// The "View Feed" button will navigate to this route and pass capsuleId as arguments.
  static const String capsuleFeedRouteName = '/capsuleFeed';

  const CapsuleDetailScreen({
    required this.capsuleId,
    Key? key,
  }) : super(key: key);

  @override
  State<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

enum _UnlockedStage { reveal, revealed, opened }

class _CapsuleDetailScreenState extends State<CapsuleDetailScreen> {
  DateTime? _unlockDate;
  String? _capsuleTitle;
  String? _capsuleDescription;
  int? _backgroundId;

  String? _ownerDisplayName;

  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isUnlocked = false;
  bool _loading = true;

  String? _error;

  _UnlockedStage _unlockedStage = _UnlockedStage.reveal;
  bool _revealLoading = false;
  bool _deleteLoading = false;

  // Optional (kept from your previous code; not required for the UI)
  bool _textLoading = false;
  List<Map<String, dynamic>> _textMemories = [];

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

  bool _isProbablyBase64(String s) {
    final v = s.trim();
    if (v.isEmpty) return false;
    if (v.length < 16) return false;
    if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(v)) return false;
    return true;
  }

  bool _looksLikeEncryptedSecretBox(String s) {
    if (!_isProbablyBase64(s)) return false;
    try {
      final decoded = utf8.decode(base64Decode(s.trim()));
      final obj = jsonDecode(decoded);
      return obj is Map &&
          obj.containsKey('nonce') &&
          obj.containsKey('cipherText') &&
          obj.containsKey('mac');
    } catch (_) {
      return false;
    }
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

      // Fetch user display name for the AppBar ("Alex's Capsule" style)
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get()
            .timeout(const Duration(seconds: 10));

        final name = (userDoc.data()?['displayName'] ?? '').toString().trim();
        _ownerDisplayName = name.isEmpty ? null : name;
      } catch (_) {
        // Not fatal
        _ownerDisplayName = null;
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

      final storedKeyValue = capsuleKeys[currentUser.uid];
      if (storedKeyValue is! String || storedKeyValue.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No capsule key found for this user.';
        });
        return;
      }

      final encryptedCapsuleKey = storedKeyValue.trim();

      // 2) Decrypt capsule key using persisted master key (new format),
      //    fall back to legacy raw base64 bytes if needed.
      final userMasterKey = UserCryptoState.userMasterKeyOrNull;

      SecretKey capsuleKey;

      if (userMasterKey != null) {
        try {
          capsuleKey = await BoxedEncryptionService.decryptCapsuleKeyForUser(
            encryptedCapsuleKey: encryptedCapsuleKey,
            userMasterKey: userMasterKey,
          );
        } catch (_) {
          if (!_isProbablyBase64(encryptedCapsuleKey) ||
              _looksLikeEncryptedSecretBox(encryptedCapsuleKey)) {
            throw Exception(
              'Capsule key format invalid. This capsule may be from an old build. Try recreating it.',
            );
          }
          capsuleKey = SecretKey(base64Decode(encryptedCapsuleKey));
        }
      } else {
        if (!_isProbablyBase64(encryptedCapsuleKey) ||
            _looksLikeEncryptedSecretBox(encryptedCapsuleKey)) {
          throw Exception('Master key missing. Please log in again.');
        }
        capsuleKey = SecretKey(base64Decode(encryptedCapsuleKey));
      }

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

      final revealedAt = data['revealedAt'];
      final alreadyRevealed = revealedAt is Timestamp;

      if (!mounted) return;
      setState(() {
        _unlockDate = unlockDate;
        _capsuleTitle = (data['name'] ?? '').toString();
        _capsuleDescription = (data['description'] ?? '').toString();
        _backgroundId =
            data['backgroundId'] is int ? data['backgroundId'] as int : null;

        _remaining = diff;
        _isUnlocked = unlocked;

        // If unlocked + revealedAt exists, consider it already opened
        _unlockedStage = unlocked
            ? (alreadyRevealed ? _UnlockedStage.opened : _UnlockedStage.reveal)
            : _UnlockedStage.reveal;

        _loading = false;
      });

      // Countdown timer
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final now = DateTime.now();
        final unlockedNow = !now.isBefore(unlockDate);

        Duration newDiff = unlockDate.difference(now);
        if (newDiff.isNegative) newDiff = Duration.zero;

        if (!mounted) return;

        if (unlockedNow && !_isUnlocked) {
          setState(() {
            _isUnlocked = true;
            _remaining = Duration.zero;
            if (_unlockedStage != _UnlockedStage.opened) {
              _unlockedStage = _UnlockedStage.reveal;
            }
          });
        } else if (!unlockedNow) {
          setState(() {
            _isUnlocked = false;
            _remaining = newDiff;
          });
        } else {
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

  // Optional: keep if you still need notes later
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

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _ownerCapsuleTitle() {
    final name = (_ownerDisplayName ?? '').trim();
    if (name.isEmpty) return 'Your Capsule';
    return name.endsWith('s') ? "$name' Capsule" : "$name's Capsule";
  }

  Future<void> _markCapsuleRevealed() async {
    if (_revealLoading) return;
    if (!mounted) return;

    setState(() => _revealLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsuleId)
          .set(
        {
          'isRevealed': true,
          'revealedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() {
        _unlockedStage = _UnlockedStage.revealed;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reveal: $e'),
          backgroundColor: const Color(0xFF2A2A2A),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _revealLoading = false);
    }
  }

  Future<void> _goToFeedThenOpen() async {
    // Optionally mark opened immediately so it's ready when they come back
    setState(() => _unlockedStage = _UnlockedStage.opened);

    await Navigator.pushNamed(
      context,
      CapsuleDetailScreen.capsuleFeedRouteName,
      arguments: widget.capsuleId,
    );

    if (!mounted) return;
    // When they return from feed, show the opened capsule screen (as requested)
    setState(() => _unlockedStage = _UnlockedStage.opened);
  }

  Future<void> _shareCapsule() async {
    final title =
        (_capsuleTitle ?? '').trim().isNotEmpty ? _capsuleTitle!.trim() : 'Capsule';
    final unlockedOn =
        _unlockDate != null ? DateFormat('dd/MM/yyyy').format(_unlockDate!) : '';
    final text = unlockedOn.isEmpty ? title : '$title\nUnlocked on: $unlockedOn';

    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied share text to clipboard.'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
    }
  }

  Future<void> _deleteCapsule() async {
    if (_deleteLoading) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Text(
            'Delete capsule?',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This will permanently delete the capsule and its memories.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    if (!mounted) return;

    setState(() => _deleteLoading = true);

    try {
      // Delete memories subcollection in batches (best-effort).
      final memRef = FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsuleId)
          .collection('memories');

      while (true) {
        final snap = await memRef.limit(300).get();
        if (snap.docs.isEmpty) break;

        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }

      // Delete capsule doc
      await FirebaseFirestore.instance
          .collection('capsules')
          .doc(widget.capsuleId)
          .delete();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete capsule: $e'),
          backgroundColor: const Color(0xFF2A2A2A),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _deleteLoading = false);
    }
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

    if (!_isUnlocked) return _buildLockedView();

    switch (_unlockedStage) {
      case _UnlockedStage.reveal:
        return _buildUnlockRevealViewDark();
      case _UnlockedStage.revealed:
        return _buildRevealedSuccessViewDark();
      case _UnlockedStage.opened:
        return _buildOpenedCapsuleViewDark();
    }
  }

  // LOCKED VIEW (countdown style)
  Widget _buildLockedView() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    final unlock = _unlockDate;
    final unlockDateStr =
        unlock != null ? DateFormat('dd/MM/yyyy').format(unlock) : '';
    final unlockTimeStr = unlock != null ? DateFormat('h:mm a').format(unlock) : '';

    const bg = Colors.black;
    final tileColor = Colors.white.withOpacity(0.10);
    final muted = Colors.white.withOpacity(0.72);
    final muted2 = Colors.white.withOpacity(0.55);
    const accent = Color(0xFFD4AF37);

    Widget timeTile({required String value, required String label}) {
      return Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: muted2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Capsule Status',
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_outline,
                    size: 44,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                "You're a bit early!",
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "This capsule is still sealed. Come back when\nthe countdown hits zero.",
                style: textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  timeTile(value: _twoDigits(days), label: 'Days'),
                  const SizedBox(width: 10),
                  timeTile(value: _twoDigits(hours), label: 'Hours'),
                  const SizedBox(width: 10),
                  timeTile(value: _twoDigits(minutes), label: 'Minutes'),
                  const SizedBox(width: 10),
                  timeTile(value: _twoDigits(seconds), label: 'Seconds'),
                ],
              ),
              const SizedBox(height: 22),
              if (unlock != null) ...[
                Text(
                  'Capsule unlocks on: $unlockDateStr',
                  style: textTheme.bodySmall?.copyWith(
                    color: muted2,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'at $unlockTimeStr',
                  style: textTheme.bodySmall?.copyWith(
                    color: muted2,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // UNLOCK REVEAL (DARK THEME)
  Widget _buildUnlockRevealViewDark() {
    final textTheme = Theme.of(context).textTheme;
    const bg = Colors.black;
    const surface = Color(0xFF2A2A2A);

    final title = (_capsuleTitle ?? '').trim().isNotEmpty
        ? _capsuleTitle!.trim()
        : 'Your Capsule';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: surface,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your memories are ready to be revealed',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.70),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _revealLoading ? null : _markCapsuleRevealed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _revealLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open),
                  label: Text(
                    _revealLoading ? 'Revealing...' : 'Reveal Memories',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This is a one-time reveal. Enjoy the moment!',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.50),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // AFTER REVEAL (DARK THEME + VIEW FEED)
  Widget _buildRevealedSuccessViewDark() {
    final textTheme = Theme.of(context).textTheme;
    const bg = Colors.black;
    const surface = Color(0xFF2A2A2A);

    final title = (_capsuleTitle ?? '').trim().isNotEmpty
        ? _capsuleTitle!.trim()
        : 'Your Capsule';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: surface,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Memories unlocked successfully!',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.72),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _goToFeedThenOpen,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'View Feed',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This is a one-time reveal. Enjoy the moment!',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.50),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // OPENED CAPSULE (DARK THEME, matches your screenshot layout)
  Widget _buildOpenedCapsuleViewDark() {
    final textTheme = Theme.of(context).textTheme;

    final capsuleTitle = (_capsuleTitle ?? '').trim().isNotEmpty
        ? _capsuleTitle!.trim()
        : 'Capsule';

    final description = (_capsuleDescription ?? '').trim();
    final unlockedOn =
        _unlockDate != null ? DateFormat('dd/MM/yyyy').format(_unlockDate!) : '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
        title: Text(
          _ownerCapsuleTitle(),
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _shareCapsule,
            icon: const Icon(Icons.share, color: Colors.white),
          ),
          _deleteLoading
              ? Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _deleteCapsule,
                  icon: const Icon(Icons.delete, color: Colors.white),
                ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            children: [
              Text(
                capsuleTitle,
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.70),
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              const Spacer(),
              if (unlockedOn.isNotEmpty)
                Text(
                  'Unlocked on: $unlockedOn',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.45),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
