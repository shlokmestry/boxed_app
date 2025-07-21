import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';

class ChooseUsernameScreen extends StatefulWidget {
  const ChooseUsernameScreen({super.key});

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _feedback;
  bool _checking = false;
  bool _isAvailable = false;

  final List<String> adjectives = [
    'Happy', 'Cosmic', 'Tiny', 'Brave', 'Chill', 'Sunny', 'Zesty', 'Loyal', 'Sneaky'
  ];
  final List<String> nouns = [
    'Penguin', 'Wizard', 'Fox', 'Otter', 'Pancake', 'Ghost', 'Capsule', 'Pixel'
  ];

  @override
  void initState() {
    super.initState();
    _suggestUsername();
  }

  void _suggestUsername() {
    final rand = Random();
    final suggestion =
        '${adjectives[rand.nextInt(adjectives.length)]}${nouns[rand.nextInt(nouns.length)]}${rand.nextInt(9999)}';
    _controller.text = suggestion;
    _checkAvailability(suggestion);
  }

  void _checkAvailability(String username) async {
    setState(() {
      _checking = true;
      _isAvailable = false;
      _feedback = null;
    });

    final trimmed = username.trim();

    if (trimmed.length < 4) {
      setState(() {
        _checking = false;
        _feedback =
            "Tiny but mighty... however, usernames need at least 4 characters.";
      });
      return;
    }
    if (trimmed.length > 16) {
      setState(() {
        _checking = false;
        _feedback =
            "That’s quite a story. Usernames can only be up to 16 characters.";
      });
      return;
    }

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      setState(() {
        _feedback =
            "This username is taken; the early bird grabs the capsule! Try a new one!";
        _checking = false;
        _isAvailable = false;
      });
    } else {
      setState(() {
        _feedback = "Just for you! This one’s looking for an owner.";
        _checking = false;
        _isAvailable = true;
      });
    }
  }

  void _confirmUsername() async {
    final username = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (!_isAvailable || username.isEmpty || user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'username': username,
      'username_lowercase': username.toLowerCase(),
    }, SetOptions(merge: true));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text("Pick Your Username",
            style: textTheme.titleLarge?.copyWith(color: colorScheme.primary)),
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Choose a unique username to mark your memories.",
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              style: TextStyle(color: colorScheme.onBackground),
              onChanged: _checkAvailability,
              decoration: InputDecoration(
                hintText: "your_awesome_name",
                filled: true,
                fillColor: colorScheme.surface,
                hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _checking
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _isAvailable
                        ? const Icon(Icons.check, color: Colors.green)
                        : const Icon(Icons.warning, color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 12),
            if (_feedback != null)
              Text(
                _feedback!,
                style: textTheme.bodySmall?.copyWith(
                  color: _isAvailable ? Colors.green : Colors.redAccent,
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _suggestUsername,
                  child: Text("Suggest New",
                      style: TextStyle(color: colorScheme.primary)),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isAvailable ? _confirmUsername : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isAvailable ? colorScheme.primary : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Next"),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
