import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'capsule_detail_screen.dart';
import 'create_capsule_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'collaborator_invites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _username;
  String? _photoUrl;
  bool _loadingUsername = true;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profileDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    setState(() {
      _username = profileDoc.data()?['username'] ?? 'User';
      _photoUrl = profileDoc.data()?['photoUrl'] ?? user.photoURL;
      _loadingUsername = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'My Capsules',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: colorScheme.background,
          iconTheme: IconThemeData(color: colorScheme.primary),
        ),
        backgroundColor: colorScheme.background,
        body: Center(
          child: Text(
            "Please sign in to view capsules",
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Capsules',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.background,
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      backgroundColor: colorScheme.background,
      drawer: _buildDrawer(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCapsuleScreen()),
          );
        },
        backgroundColor: colorScheme.primary,
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('capsules')
            .where('memberIds', arrayContains: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading capsules:\n${snapshot.error}',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No capsules found.",
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['name'] ?? '';
              final emoji = data['emoji'] ?? '📦';
              final Timestamp? unlockTimestamp = data['unlockDate'];
              DateTime unlockDate;
              if (unlockTimestamp != null) {
                unlockDate = unlockTimestamp.toDate();
              } else {
                unlockDate = DateTime.now();
              }

              final isUnlocked = DateTime.now().isAfter(unlockDate);
              final status = data['status'] ?? 'active';
              final isPending = status == 'pending';

              return CapsuleCard(
                title: title,
                emoji: emoji,
                unlockDate: unlockDate,
                isUnlocked: isUnlocked,
                isPending: isPending,
                onTap: isPending
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CapsuleDetailScreen(
                              capsuleId: doc.id,
                            ),
                          ),
                        );
                      },
              );
            },
          );
        },
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final avatar =
        _photoUrl != null ? NetworkImage(_photoUrl!) : null;
    final initials =
        (_username != null && _username!.isNotEmpty)
            ? _username![0].toUpperCase()
            : 'U';

    return Drawer(
      backgroundColor: colorScheme.background,
      elevation: 0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (profile photo & username, with loader)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.primary.withOpacity(0.14),
                      backgroundImage: avatar,
                      child: avatar == null
                          ? Text(
                              initials,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    _loadingUsername
                        ? SizedBox(
                            width: 80,
                            height: 18,
                            child: LinearProgressIndicator(
                              backgroundColor:
                                  colorScheme.onBackground.withOpacity(0.08),
                              color: colorScheme.primary,
                              minHeight: 3,
                            ),
                          )
                        : Text(
                            _username ?? "",
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onBackground,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: 0.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            _DrawerMenuItem(
              label: 'My Capsules',
              onTap: () => Navigator.pop(context),
              fontSize: 16,
            ),
            const SizedBox(height: 11),
            _DrawerMenuItem(
              label: 'Collaborators',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CollaboratorInvitesScreen()),
                );
              },
              fontSize: 16,
            ),
            const SizedBox(height: 11),
            _DrawerMenuItem(
              label: 'Shared With Me',
              onTap: () {
                Navigator.pop(context);
                _showSnack(context, "Shared Capsules coming soon");
              },
              fontSize: 16,
            ),
            const SizedBox(height: 11),

            // Themes removed from drawer

            _DrawerMenuItem(
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              fontSize: 16,
            ),
            const Spacer(),
            _DrawerMenuItem(
              label: 'Sign Out',
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
              fontSize: 18, // increased font size for visibility
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;

  const _DrawerMenuItem({
    required this.label,
    required this.onTap,
    this.fontSize = 16,
    this.color,
    this.fontWeight,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 23),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: color ?? Theme.of(context).colorScheme.onSurface,
              fontSize: fontSize,
              fontWeight: fontWeight ?? FontWeight.w500,
              letterSpacing: 0.05,
            ),
          ),
        ),
      ),
    );
  }
}

// CapsuleCard remains unchanged from previous version
class CapsuleCard extends StatelessWidget {
  final String title;
  final String emoji;
  final DateTime unlockDate;
  final bool isUnlocked;
  final bool isPending;
  final VoidCallback? onTap;

  const CapsuleCard({
    required this.title,
    required this.emoji,
    required this.unlockDate,
    required this.isUnlocked,
    this.isPending = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final unlockLabel = isUnlocked
        ? 'Unlocked on ${DateFormat.yMMMd().format(unlockDate)}'
        : 'Unlocks in ${_formatCountdown(unlockDate)}';

    return Opacity(
      opacity: isPending ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          color: colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$emoji $title',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        unlockLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Pending collaborators acceptance',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline,
                  color: isUnlocked
                      ? Colors.greenAccent
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCountdown(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'less than a minute';
    }
  }
}
