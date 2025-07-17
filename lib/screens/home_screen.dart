import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:boxed_app/screens/create_capsule_screen.dart';
import 'package:boxed_app/screens/capsule_detail_screen.dart';
import 'package:boxed_app/screens/profile_screen.dart';
import 'package:intl/intl.dart';
import 'package:boxed_app/screens/settings_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Capsules',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.background,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.primary),
        elevation: 0,
      ),
      drawer: Drawer(
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
                icon: Icons.mail_outline,
                label: 'Invites',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Invites coming soon"),
                      backgroundColor: colorScheme.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _DrawerButton(
                icon: Icons.group,
                label: 'Shared With Me',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Shared Capsules coming soon"),
                      backgroundColor: colorScheme.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _DrawerButton(
                icon: Icons.color_lens_outlined,
                label: 'Themes',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Themes feature coming soon"),
                      backgroundColor: colorScheme.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
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
      ),
      backgroundColor: colorScheme.background,
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
      body: user == null
          ? Center(
              child: Text(
                "Please sign in to view capsules",
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onBackground,
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('capsules')
                  .where('memberIds', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No capsules found.",
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onBackground,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['name'] ?? '';
                    final emoji = data['emoji'] ?? '';
                    final unlockDate = (data['unlockDate'] as Timestamp).toDate();
                    final isUnlocked = DateTime.now().isAfter(unlockDate);

                    return CapsuleCard(
                      title: title,
                      emoji: emoji,
                      unlockDate: unlockDate,
                      isUnlocked: isUnlocked,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CapsuleDetailScreen(
                              capsuleId: docs[index].id,
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
}

class CapsuleCard extends StatelessWidget {
  final String title;
  final String emoji;
  final DateTime unlockDate;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const CapsuleCard({
    required this.title,
    required this.emoji,
    required this.unlockDate,
    required this.isUnlocked,
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

    return GestureDetector(
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
                  ],
                ),
              ),
              isUnlocked
                  ? Icon(Icons.lock_open_rounded, color: Colors.greenAccent)
                  : Icon(Icons.lock_outline, color: colorScheme.onSurface.withOpacity(0.6)),
            ],
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
