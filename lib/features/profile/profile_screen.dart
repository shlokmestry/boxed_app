import 'dart:io';
import 'package:boxed_app/features/profile/edit_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

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

    // Get capsule count
    final capsSnap = await FirebaseFirestore.instance
        .collection('capsules')
        .where('creatorId', isEqualTo: user.uid)
        .get();
    final count = capsSnap.size;

    return {
      ...data,
      'capsulesCount': count,
    };
  }

  Future<String?> _uploadAvatar(String path, String userId) async {
    try {
      final ref =
          FirebaseStorage.instance.ref().child('avatars').child(userId);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Profile", style: textTheme.titleLarge),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final data = await _getUserProfile();
              final username = data?['username'] ?? 'myprofile';
              final shareLink = "https://boxed.app/u/$username";
              Share.share("Check out my Boxed profile: $shareLink");
            },
          ),
        ],
      ),
      backgroundColor: colorScheme.background,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserProfile(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Text("No profile data found.",
                  style: textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onBackground)),
            );
          }

          final firstName = data['firstName'] ?? '';
          final lastName = data['lastName'] ?? '';
          final username = data['username'] ?? '';
          final photoUrl = data['photoUrl'];
          final createdAt = data['createdAt']?.toDate();
          final capsulesCount = data['capsulesCount'] ?? 0;

          final String initials = (firstName.isNotEmpty ? firstName[0] : '') +
              (lastName.isNotEmpty ? lastName[0] : '');

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// Avatar with tap and upload logic
                GestureDetector(
                  onTap: () async {
                    final picked = await _picker.pickImage(
                        source: ImageSource.gallery);
                    if (picked != null) {
                      setState(() => _isUploadingAvatar = true);
                      final newUrl = await _uploadAvatar(
                          picked.path, FirebaseAuth.instance.currentUser!.uid);
                      setState(() => _isUploadingAvatar = false);
                      if (newUrl != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Avatar updated!")),
                        );
                      }
                      setState(() {}); // To refresh avatar
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: (photoUrl != null && photoUrl != '')
                            ? NetworkImage(photoUrl)
                            : null,
                        backgroundColor: colorScheme.surface,
                        child: (photoUrl == null || photoUrl == '')
                            ? Text(
                                initials.isNotEmpty
                                    ? initials.toUpperCase()
                                    : username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : "?",
                                style: textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (_isUploadingAvatar)
                        const CircularProgressIndicator(strokeWidth: 2),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  username,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$capsulesCount',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  "Capsules Created",
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                if (createdAt != null)
                  Text(
                    "user since: ${DateFormat('MM/yyyy').format(createdAt)}",
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()),
                      );
                      if (updated == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Profile updated!"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text("Edit Profile"),
                  ),
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}
