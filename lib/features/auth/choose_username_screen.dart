import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../capsules/screens/home_screen.dart';

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
  bool _isSaving = false;

  final List<String> adjectives = [
    'Happy', 'Cosmic', 'Tiny', 'Brave', 'Chill', 'Sunny', 'Zesty', 'Loyal', 
    'Sneaky', 'Swift', 'Mystic', 'Noble', 'Wild', 'Cool', 'Clever', 'Bold'
  ];
  
  final List<String> nouns = [
    'Penguin', 'Wizard', 'Fox', 'Otter', 'Pancake', 'Ghost', 'Capsule', 
    'Pixel', 'Dragon', 'Phoenix', 'Tiger', 'Eagle', 'Wolf', 'Bear', 'Lion'
  ];

  @override
  void initState() {
    super.initState();
    _checkIfUserAlreadyHasUsername();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Check if user somehow already has a username and navigate accordingly
  Future<void> _checkIfUserAlreadyHasUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No user found in ChooseUsernameScreen');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final existingUsername = doc.data()?['username'];
      if (existingUsername != null && existingUsername.toString().trim().isNotEmpty) {
        debugPrint('User already has username: $existingUsername, navigating to home');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
        return;
      }

      // User doesn't have username yet, suggest one
      _suggestUsername();
    } catch (e) {
      debugPrint('Error checking existing username: $e');
      _suggestUsername();
    }
  }

  String _generateUsername() {
    final rand = Random();
    return '${adjectives[rand.nextInt(adjectives.length)]}${nouns[rand.nextInt(nouns.length)]}${rand.nextInt(9999)}';
  }

  void _suggestUsername() {
    final suggestion = _generateUsername();
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

    if (trimmed.isEmpty) {
      setState(() {
        _checking = false;
        _feedback = "Username cannot be empty.";
      });
      return;
    }

    if (trimmed.length < 3) {
      setState(() {
        _checking = false;
        _feedback = "Username must be at least 3 characters.";
      });
      return;
    }
    
    if (trimmed.length > 20) {
      setState(() {
        _checking = false;
        _feedback = "Username must be 20 characters or less.";
      });
      return;
    }

    // Check for invalid characters
    final validUsername = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validUsername.hasMatch(trimmed)) {
      setState(() {
        _checking = false;
        _feedback = "Username can only contain letters, numbers, and underscores.";
      });
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lowercase', isEqualTo: trimmed.toLowerCase())
          .limit(1)
          .get();

      if (!mounted) return;

      if (query.docs.isNotEmpty) {
        setState(() {
          _feedback = "This username is taken. Try another!";
          _checking = false;
          _isAvailable = false;
        });
      } else {
        setState(() {
          _feedback = "Just for you! This one's looking for an owner.";
          _checking = false;
          _isAvailable = true;
        });
      }
    } catch (e) {
      debugPrint('🔴 Error checking username availability: $e');
      if (mounted) {
        setState(() {
          _feedback = "Error checking username. Please try again.";
          _checking = false;
          _isAvailable = false;
        });
      }
    }
  }

  void _confirmUsername() async {
    final username = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (!_isAvailable || username.isEmpty || user == null) {
      debugPrint('Cannot confirm username: available=$_isAvailable, username=$username, user=${user?.uid}');
      return;
    }

    setState(() => _isSaving = true);

    try {
      debugPrint('Setting username: $username for user: ${user.uid}');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'username': username,
        'username_lowercase': username.toLowerCase(),
      }, SetOptions(merge: true));

      debugPrint('Username saved successfully');

      if (!mounted) return;

      // Use pushAndRemoveUntil to prevent going back to username screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );

      debugPrint('Navigated to home screen');
    } catch (e) {
      debugPrint('Error saving username: $e');
      
      if (mounted) {
        setState(() {
          _isSaving = false;
          _feedback = "Error saving username. Please try again.";
          _isAvailable = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save username: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {}, // Disabled - can't go back
          ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Avatar/Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 40,
                    color: Colors.purple[300],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'Pick your username',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'This is how friends will find and tag you in\nshared memories',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Username label
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Username',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Username input field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAvailable 
                          ? Colors.green 
                          : (_feedback != null && !_checking && !_isAvailable)
                              ? Colors.red
                              : Colors.grey[800]!,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    enabled: !_isSaving,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    onChanged: _checkAvailability,
                    decoration: InputDecoration(
                      hintText: 'yourname',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Text(
                          '@',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      suffixIcon: _checking || _isSaving
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.purple,
                                ),
                              ),
                            )
                          : _isAvailable
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Character limit text
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '3-20 characters, letters, numbers, underscore, dots, and dashes only',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Feedback message
                if (_feedback != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isAvailable 
                          ? Colors.green.withOpacity(0.1) 
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isAvailable ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isAvailable ? Icons.check_circle : Icons.info_outline,
                          color: _isAvailable ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _feedback!,
                            style: TextStyle(
                              color: _isAvailable ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 32),
                
                // Continue / Suggest New button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isAvailable && !_isSaving) ? _confirmUsername : _suggestUsername,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isAvailable ? 'Continue' : 'Suggest New',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}