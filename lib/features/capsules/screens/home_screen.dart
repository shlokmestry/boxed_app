
import 'package:boxed_app/core/services/boxed_encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:boxed_app/features/Settings/Misc/settings_screen.dart';
import 'package:boxed_app/features/capsules/state/capsule_controller.dart';
import 'package:boxed_app/features/profile/profile_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'capsule_detail_screen.dart';
import 'create_capsule_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<CapsuleController>().loadCapsules(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colorScheme.background,
        drawer: _buildDrawer(context),
        appBar: AppBar(
          title: const Text('My Capsules'),
          centerTitle: true,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ProfileAvatarButton(
                user: user,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _AddCapsuleButton(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateCapsuleScreen()),
            );
          },
        ),
        body: user == null ? _signedOutEmpty(context) : _capsulesBody(context, user),
      ),
    );
  }

  Widget _signedOutEmpty(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        'Please sign in to view capsules',
        style: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onBackground.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _capsulesBody(BuildContext context, User user) {
    final controller = context.watch<CapsuleController>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    switch (controller.state) {
      case CapsuleLoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case CapsuleLoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              controller.error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
            ),
          ),
        );

      case CapsuleLoadState.empty:
        return _contentScaffold(
          context,
          allCapsules: const [],
          unlockedCapsules: const [],
          userId: user.uid,
        );

      case CapsuleLoadState.ready:
        final all = controller.capsules;

        final filteredAll = _applySearch(all);
        final filteredUnlocked = _applySearch(
          all.where((c) {
            final ts = c['unlockDate'];
            final unlockDate = ts is Timestamp ? ts.toDate() : DateTime.now();
            return DateTime.now().isAfter(unlockDate);
          }).toList(),
        );

        return _contentScaffold(
          context,
          allCapsules: filteredAll,
          unlockedCapsules: filteredUnlocked,
          userId: user.uid,
        );

      case CapsuleLoadState.idle:
      return const SizedBox.shrink();
    }
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> capsules) {
    if (_query.isEmpty) return capsules;

    return capsules.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      return name.contains(_query) || desc.contains(_query);
    }).toList();
  }

  Widget _contentScaffold(
    BuildContext context, {
    required List<Map<String, dynamic>> allCapsules,
    required List<Map<String, dynamic>> unlockedCapsules,
    required String userId,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            hintText: 'Search capsules',
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.65),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Unlocked'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _CapsulesList(
                  userId: userId,
                  capsules: allCapsules,
                  emptyText: 'No capsules found.',
                ),
                _CapsulesList(
                  userId: userId,
                  capsules: unlockedCapsules,
                  emptyText: 'No unlocked capsules yet.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final displayName = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();
    final initials = (displayName.isNotEmpty)
        ? displayName.characters.first.toUpperCase()
        : (email.isNotEmpty ? email.characters.first.toUpperCase() : 'B');

    return Drawer(
      backgroundColor: colorScheme.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colorScheme.primary.withOpacity(0.12),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Boxed',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onBackground,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onBackground.withOpacity(0.65),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DrawerItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const Spacer(),
              _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                destructive: true,
                onTap: () async {
                  Navigator.pop(context);

                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await BoxedEncryptionService.clearUserMasterKey(uid);
                  }
                  UserCryptoState.clear();
                  await FirebaseAuth.instance.signOut();

                  if (context.mounted) {
                    context.read<CapsuleController>().clear();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapsulesList extends StatelessWidget {
  final String userId;
  final List<Map<String, dynamic>> capsules;
  final String emptyText;

  const _CapsulesList({
    required this.userId,
    required this.capsules,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CapsuleController>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (capsules.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onBackground.withOpacity(0.65),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.loadCapsules(userId),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: capsules.length,
        itemBuilder: (context, index) {
          final c = capsules[index];

          final title = (c['name'] ?? '').toString();
          final emoji = (c['emoji'] ?? '📦').toString();

          final ts = c['unlockDate'];
          final unlockDate = ts is Timestamp ? ts.toDate() : DateTime.now();

          final isUnlocked = DateTime.now().isAfter(unlockDate);

          return _CapsuleRowCard(
            title: title,
            emoji: emoji,
            unlockDate: unlockDate,
            isUnlocked: isUnlocked,
            onTap: () {
              final capsuleId = (c['capsuleId'] ?? '').toString();
              if (capsuleId.isEmpty) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CapsuleDetailScreen(capsuleId: capsuleId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CapsuleRowCard extends StatelessWidget {
  final String title;
  final String emoji;
  final DateTime unlockDate;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const _CapsuleRowCard({
    required this.title,
    required this.emoji,
    required this.unlockDate,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final subtitle = isUnlocked
        ? 'Unlocked'
        : 'Unlocks ${_relativeUnlockLabel(unlockDate)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Untitled capsule' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Unlocked',
                      style: textTheme.labelMedium?.copyWith(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.lock_outline_rounded,
                    color: colorScheme.onSurface.withOpacity(0.55),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _relativeUnlockLabel(DateTime unlock) {
    final now = DateTime.now();
    final diff = unlock.difference(now);

    if (diff.inSeconds <= 0) return 'now';
    if (diff.inDays >= 1) return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours >= 1) return 'in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    if (diff.inMinutes >= 1) return 'in ${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'}';
    return 'soon';
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _SearchBar({
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colorScheme.onSurface.withOpacity(0.55)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.45)),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () => controller.clear(),
              child: Icon(Icons.close_rounded, color: colorScheme.onSurface.withOpacity(0.55)),
            ),
        ],
      ),
    );
  }
}

class _AddCapsuleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCapsuleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.add_rounded),
    );
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  final User? user;
  final VoidCallback onTap;

  const _ProfileAvatarButton({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();
    final photoUrl = (user?.photoURL ?? '').trim();

    final initials = (displayName.isNotEmpty)
        ? displayName.characters.first.toUpperCase()
        : (email.isNotEmpty ? email.characters.first.toUpperCase() : 'B');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: colorScheme.primary.withOpacity(0.12),
        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isNotEmpty
            ? null
            : Text(
                initials,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = destructive ? colorScheme.error : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outline.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                Icon(icon, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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
        ),
      ),
    );
  }
}
