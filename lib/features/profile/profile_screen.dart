import 'dart:io';

import 'package:boxed_app/core/services/boxed_encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:boxed_app/features/Settings/Misc/faq_screen.dart';
import 'package:boxed_app/features/Settings/Misc/settings_screen.dart';
import 'package:boxed_app/features/profile/edit_profile_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  Future<Map<String, dynamic>?> _getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    // Capsule count (solo MVP)
    final capsSnap = await FirebaseFirestore.instance
        .collection('capsules')
        .where('creatorId', isEqualTo: user.uid)
        .get();

    return {
      ...data,
      'capsulesCount': capsSnap.size,
    };
  }

  Future<String?> _uploadAvatar(String path, String userId) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('avatars').child(userId);
      final uploadTask = ref.putFile(File(path));
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'photoUrl': url});

      return url;
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      return null;
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    final newUrl = await _uploadAvatar(picked.path, user.uid);
    setState(() => _isUploadingAvatar = false);

    if (!mounted) return;

    if (newUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated!')),
      );
      setState(() {}); // refresh FutureBuilder
    }
  }

  Future<void> _logout() async {
    Navigator.of(context).pop(); // close drawer/dialogs if any

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await BoxedEncryptionService.clearUserMasterKey(uid);
    }
    UserCryptoState.clear();
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text('Profile', style: textTheme.titleLarge),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final data = await _getUserProfile();
              final username = (data?['username'] ?? 'myprofile').toString();
              final shareLink = "https://boxed.app/u/$username";
              Share.share("Check out my Boxed profile: $shareLink");
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Text(
                'No profile data found.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.85),
                ),
              ),
            );
          }

          final firstName = (data['firstName'] ?? '').toString();
          final lastName = (data['lastName'] ?? '').toString();
          final username = (data['username'] ?? '').toString();
          final photoUrl = (data['photoUrl'] ?? '').toString();
          final createdAt = data['createdAt'];
          final createdAtDate =
              createdAt is Timestamp ? createdAt.toDate() : null;

          final capsulesCount = (data['capsulesCount'] ?? 0) as int;

          final initials = ((firstName.isNotEmpty ? firstName[0] : '') +
                  (lastName.isNotEmpty ? lastName[0] : ''))
              .trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              // Header
              Center(
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: colorScheme.surface,
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isNotEmpty
                            ? null
                            : Text(
                                (initials.isNotEmpty
                                        ? initials
                                        : (username.isNotEmpty
                                            ? username[0]
                                            : '?'))
                                    .toUpperCase(),
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                      ),
                      if (_isUploadingAvatar)
                        const SizedBox(
                          height: 28,
                          width: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Center(
                child: Text(
                  username.isNotEmpty ? username : 'User',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onBackground,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              if (createdAtDate != null)
                Center(
                  child: Text(
                    'Member since ${DateFormat('MMM yyyy').format(createdAtDate)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.60),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // Minimal stat (keep only capsules)
              _PillStat(
                label: 'Capsules',
                value: capsulesCount.toString(),
              ),

              const SizedBox(height: 14),

              // Edit profile button
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                    if (updated == true && mounted) {
                      setState(() {});
                    }
                  },
                  child: const Text('Edit profile'),
                ),
              ),

              const SizedBox(height: 16),

              // Actions (no headers like Account/App/Danger zone)
              _CardGroup(
                children: [
                  _GroupTile(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  _GroupDivider(),
                  _GroupTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & support',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FaqScreen()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _CardGroup(
                children: [
                  _GroupTile(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    destructive: true,
                    onTap: () async => _logout(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  final String label;
  final String value;

  const _PillStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  final List<Widget> children;

  const _CardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
      ),
      child: Column(children: children),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      color: colorScheme.outline.withOpacity(0.10),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _GroupTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final fg = destructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withOpacity(0.35),
            ),
          ],
        ),
      ),
    );
  }
}
