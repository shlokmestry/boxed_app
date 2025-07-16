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

    // Check length
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Pick Your Username"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Choose a unique username to mark your memories.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              onChanged: _checkAvailability,
              decoration: InputDecoration(
                hintText: "your_awesome_name",
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(color: Colors.grey),
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
                style: TextStyle(
                  color: _isAvailable ? Colors.green : Colors.redAccent,
               
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _suggestUsername,
                  child: const Text("Suggest New",
                      style: TextStyle(color: Colors.white70)),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isAvailable ? _confirmUsername : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAvailable ? Colors.blue : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
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
