import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/dart.dart';
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
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      // User is not logged in
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
          // Error handling
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading capsules:\n${snapshot.error}',
                style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
            );
          }

          // While waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // No data or no documents
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

              // Defensive null check on unlockDate
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
                    ? null // Disable tap if still pending
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

    return Drawer(
      backgroundColor: colorScheme.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Boxed',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _DrawerButton(
              icon: Icons.folder_special,
              label: 'My Capsules',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerButton(
              icon: Icons.person,
              label: 'My Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            _DrawerButton(
              icon: Icons.group_rounded,
              label: 'Collaborators',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CollaboratorInvitesScreen()),
                );
              },
            ),
            _DrawerButton(
              icon: Icons.group,
              label: 'Shared With Me',
              onTap: () {
                Navigator.pop(context);
                _showSnack(context, "Shared Capsules coming soon");
              },
            ),
            _DrawerButton(
              icon: Icons.color_lens_outlined,
              label: 'Themes',
              onTap: () {
                Navigator.pop(context);
                _showSnack(context, "Themes feature coming soon");
              },
            ),
            _DrawerButton(
              icon: Icons.settings,
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
            _DrawerButton(
              icon: Icons.logout,
              label: 'Sign Out',
              iconColor: Colors.redAccent,
              textColor: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
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
      opacity: isPending ? 0.6 : 1.0, // Dim if pending
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

class _DrawerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseIconColor = iconColor ?? colorScheme.onSurface;
    final baseTextColor = textColor ?? colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: baseIconColor),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: baseTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
