import 'dart:io';
import 'package:boxed_app/features/auth/login_signup.dart';

import 'package:boxed_app/core/services/boxed_encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';

import 'package:boxed_app/features/Settings/Misc/settings_screen.dart';
import 'package:boxed_app/features/profile/edit_profile_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
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

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    // Capsule count
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
        const SnackBar(
          content: Text('Avatar updated!'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      setState(() {}); // refresh FutureBuilder
    }
  }

 Future<void> _logout() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    await BoxedEncryptionService.clearUserMasterKey(uid);
  }
  UserCryptoState.clear();
  await FirebaseAuth.instance.signOut();

  if (!mounted) return;

  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginSignup()),
    (_) => false,
  );
}

  String _getInitials(String firstName, String lastName) {
    final initials = ((firstName.isNotEmpty ? firstName[0] : '') +
            (lastName.isNotEmpty ? lastName[0] : ''))
        .trim();
    return initials.isNotEmpty ? initials.toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Text(
                'No profile data found.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                ),
              ),
            );
          }

          final firstName = (data['firstName'] ?? '').toString();
          final lastName = (data['lastName'] ?? '').toString();
          final username = (data['username'] ?? '').toString();
          final photoUrl = (data['photoUrl'] ?? '').toString();
          final createdAt = data['createdAt'];
          final createdAtDate = createdAt is Timestamp ? createdAt.toDate() : null;
          final capsulesCount = (data['capsulesCount'] ?? 0) as int;

          final displayName = '$firstName $lastName'.trim();
          final memberSinceYear = createdAtDate?.year.toString() ?? '';

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    kToolbarHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Gradient header section
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                      child: Column(
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    image: photoUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(photoUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: photoUrl.isEmpty
                                      ? Center(
                                          child: Text(
                                            _getInitials(firstName, lastName),
                                            style: const TextStyle(
                                              color: Color(0xFF8B5CF6),
                                              fontSize: 36,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                if (_isUploadingAvatar)
                                  const SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Name and verified badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                displayName.isNotEmpty ? displayName : 'User',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Username
                          Text(
                            '@${username.isNotEmpty ? username : 'username'}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Black content section
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Member since
                            if (memberSinceYear.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Text(
                                  'Member since $memberSinceYear',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            // Capsules count - simple text format
                            Column(
                              children: [
                                Text(
                                  capsulesCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Capsules',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            
                            const Spacer(),

                            // Sign Out text at very bottom center
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: GestureDetector(
                                onTap: _logout,
                                child: const Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFF1A1A1A),
      indent: 16,
      endIndent: 16,
    );
  }
}