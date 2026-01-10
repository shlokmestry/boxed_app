import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Stub for collaborators - replace with actual fetch if needed
  List<String> _collaborators = [];

  final List<String> _backgroundImages = [
    'assets/basic_background1.jpg',
    'assets/basic_background2.webp',
    'assets/basic_background3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCapsuleDetails();
    _fetchCollaborators();
  }

  void _fetchCollaborators() {
    // TODO: Fetch collaborators from Firestore and update _collaborators list
    // For demo, we simulate no collaborators or some collaborators
    // Example:
    // setState(() => _collaborators = ['Anna', 'Bob', 'Chris']);
  }

  void _fetchCapsuleDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('capsules')
        .doc(widget.capsuleId)
        .get();

    final data = doc.data();
    if (data == null) return;

    // ============================
    // ✅ STEP 6: Decrypt capsule key from capsuleKeys[uid]
    // ============================
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // If user is not signed in, we can't decrypt anything.
      setState(() => _loading = false);
      return;
    }

    final encryptedCapsuleKey = (data['capsuleKeys'] as Map?)?[currentUser.uid];
    if (encryptedCapsuleKey != null) {
      try {
        final capsuleKey = await BoxedEncryptionService.decryptCapsuleKeyForUser(
          encryptedCapsuleKey: encryptedCapsuleKey,
          userMasterKey: UserCryptoState.userMasterKey,
        );

        CapsuleCryptoState.setCapsuleKey(widget.capsuleId, capsuleKey);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decrypt capsule key: $e')),
        );
      }
    }

    // ============================
    // Metadata (unchanged)
    // ============================
    final ts = data['unlockDate'];
    final title = data['name'];
    final description = data['description'];
    final bgId = data['backgroundId'];

    if (ts != null) {
      final date = (ts as Timestamp).toDate();
      final now = DateTime.now();
      final unlocked = now.isAfter(date);

      setState(() {
        _unlockDate = date;
        _capsuleTitle = title;
        _capsuleDescription = description;
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
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // ✅ STEP 6: clear decrypted capsule key from memory on exit
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Capsule title centered at top with back button
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
                      style:
                          textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),

                  Expanded(
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
                          return const SizedBox.shrink();
                        }

                        final memories = snapshot.data!.docs;
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: memories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final memory =
                                memories[index].data() as Map<String, dynamic>;
                            return _buildImageMemory(memory);
                          },
                        );
                      },
                    ),
                  ),

                  if (_collaborators.isNotEmpty || _unlockDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_collaborators.isNotEmpty)
                            _CollaboratorAvatars(
                              collaborators: _collaborators,
                            ),
                          if (_unlockDate != null)
                            Text(
                              'Unlocked on: ${DateFormat.yMMMd().add_jm().format(_unlockDate!)}',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                        ],
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
        memory['contentUrl'] ?? '',
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

class _CollaboratorAvatars extends StatelessWidget {
  final List<String> collaborators;

  const _CollaboratorAvatars({required this.collaborators, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final visibleCount = collaborators.length > 5 ? 5 : collaborators.length;

    return SizedBox(
      width: 30.0 * visibleCount,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(visibleCount, (index) {
          final nameOrInitial = collaborators[index];
          return Positioned(
            left: index * 22.0,
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white24,
              child: Text(
                nameOrInitial.isNotEmpty
                    ? nameOrInitial[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
