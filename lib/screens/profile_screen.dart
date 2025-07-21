import 'package:boxed_app/screens/edit_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<DocumentSnapshot?> _getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("My Profile", style: textTheme.titleMedium),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final doc = await _getUserProfile();
              final data = doc?.data() as Map<String, dynamic>?;
              final username = data?['username'] ?? 'myprofile';
              final shareLink = "https://boxed.app/u/$username";
              Share.share("Check out my Boxed profile: $shareLink");
            },
          ),
        ],
      ),
      backgroundColor: colorScheme.background,
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getUserProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;

          if (data == null) {
            return Center(
              child: Text("No profile data found.",
                  style: textTheme.bodyLarge?.copyWith(color: colorScheme.onBackground)),
            );
          }

          final firstName = data['firstName'] ?? '';
          final lastName = data['lastName'] ?? '';
          final username = data['username'] ?? '';
          final email = data['email'] ?? '';
          final photoUrl = data['photoUrl'];
          final createdAt = data['createdAt']?.toDate();
          final fullName = "$firstName $lastName";

          final String initials = (firstName.isNotEmpty ? firstName[0] : '') +
              (lastName.isNotEmpty ? lastName[0] : '');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 48,
                backgroundImage:
                    (photoUrl != null && photoUrl != '') ? NetworkImage(photoUrl) : null,
                backgroundColor: colorScheme.surface,
                child: (photoUrl == null || photoUrl == '')
                    ? Text(
                        initials.toUpperCase(),
                        style: textTheme.headlineMedium?.copyWith(color: colorScheme.onSurface),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                username,
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("0 achievements",
                      style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.6))),
                  const SizedBox(width: 8),
                  Text('•', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface)),
                  const SizedBox(width: 8),
                  Text("0 followers",
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.6),
                      )),
                ],
              ),
              const SizedBox(height: 8),
              if (email.isNotEmpty)
                Text("u/$email",
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    )),
              if (createdAt != null)
                Text("${createdAt.month}/${createdAt.year}",
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    )),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                  setState(() {}); // Reload profile after edit
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text("Edit Profile"),
              ),
              const SizedBox(height: 24),

              // Divider & Section Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Divider(
                      color: colorScheme.onSurface.withOpacity(0.2),
                      thickness: 0.5,
                      height: 32,
                    ),
                    Text(
                      "Your Capsules",
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onBackground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Expanded(
                child: Center(
                  child: Text(
                    "Start your first memory capsule 🎁",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
