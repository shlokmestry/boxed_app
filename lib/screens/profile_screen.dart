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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
        backgroundColor: Colors.black,
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
      backgroundColor: Colors.black,
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getUserProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text("No profile data found.", style: TextStyle(color: Colors.white)));
          }

          final firstName = data['firstName'] ?? '';
          final lastName = data['lastName'] ?? '';
          final username = data['username'] ?? '';
          final email = data['email'] ?? '';
          final photoUrl = data['photoUrl'];
          final createdAt = data['createdAt']?.toDate();
          final fullName = "$firstName $lastName";

          return Column(
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 48,
                backgroundImage: (photoUrl != null && photoUrl != '') ? NetworkImage(photoUrl) : null,
                backgroundColor: Colors.grey[800],
                child: (photoUrl == null || photoUrl == '')
                    ? Text(
                        "${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}".toUpperCase(),
                        style: const TextStyle(fontSize: 28, color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(username, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("0 achievements", style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  const Text("•", style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  const Text("0 followers", style: TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              if (email.isNotEmpty) Text("u/$email", style: const TextStyle(color: Colors.grey)),
              if (createdAt != null)
                Text("${createdAt.month}/${createdAt.year}", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                  setState(() {}); // Refresh after returning from edit screen
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text("Edit Profile"),
              ),
              const SizedBox(height: 24),
              Column(
                children: const [
                  Divider(
                    color: Colors.white24,
                    thickness: 0.5,
                    height: 32,
                    indent: 24,
                    endIndent: 24,
                  ),
                  Text(
                    "Your Capsules",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12),
                ],
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: Center(
                  child: Text("Start your first memory capsule 🎁", style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
