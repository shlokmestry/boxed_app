import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          final bio = data['bio'] ?? '';
          final createdAt = data['createdAt']?.toDate();

          final fullName = "$firstName $lastName";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  backgroundColor: Colors.grey[800],
                  child: photoUrl == null
                      ? Text(
                          "${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}".toUpperCase(),
                          style: const TextStyle(fontSize: 28, color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("@$username", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 16),
                if (email.isNotEmpty) Text(email, style: const TextStyle(color: Colors.grey)),
                if (createdAt != null)
                  Text("Member since ${createdAt.month}/${createdAt.year}", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                if (bio.isNotEmpty)
                  Text(
                    bio,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStat("Capsules", 0),
                    const SizedBox(width: 24),
                    _buildStat("Memories", 0),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to edit profile screen
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  child: const Text("Edit Profile"),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: false, // TODO: Load from user settings
                  onChanged: (value) {
                    // TODO: Toggle dark mode preference
                  },
                  title: const Text("Dark Mode", style: TextStyle(color: Colors.white)),
                  activeColor: Colors.blueAccent,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text("Sign Out", style: TextStyle(color: Colors.redAccent)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
