import 'dart:math';

import 'package:boxed_app/core/widgets/buttons.dart';
import 'package:boxed_app/features/auth/choose_username_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../capsules/screens/home_screen.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';

class LoginSignup extends StatefulWidget {
  const LoginSignup({super.key});

  @override
  State<LoginSignup> createState() => _LoginSignupState();
}

class _LoginSignupState extends State<LoginSignup> {
  bool isLogin = true;
  bool obscurePassword = true;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? emailError;
  String? passwordError;

  // ─────────────────────────────────────────────
  // Encryption salt generator (signup only)
  // ─────────────────────────────────────────────
  String _generateEncryptionSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _logFcmToken();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _requestNotificationPermission() async {
    await FirebaseMessaging.instance.requestPermission();
  }

  void _logFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('📱 FCM Token: $token');
  }

  void _showFieldErrors({String? emailMsg, String? passwordMsg}) {
    setState(() {
      emailError = emailMsg;
      passwordError = passwordMsg;
    });
  }

  String _capitalize(String input) =>
      input.isEmpty ? '' : input[0].toUpperCase() + input.substring(1);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Welcome to Boxed',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Your memories, waiting patiently.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Email
              TextField(
                controller: emailController,
                onChanged: (_) {
                  if (emailError != null) {
                    setState(() => emailError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Email',
                  errorText: emailError,
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Password
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                onChanged: (_) {
                  if (passwordError != null) {
                    setState(() => passwordError = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Password',
                  errorText: passwordError,
                  filled: true,
                  fillColor: colorScheme.surface,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Buttons(
                label: isLogin ? 'Log In' : 'Sign Up',
                onPressed: _handleAuth,
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin
                        ? "Don't have an account?"
                        : "Already have an account?",
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isLogin = !isLogin;
                        emailError = null;
                        passwordError = null;
                      });
                    },
                    child: Text(
                      isLogin ? " Sign up" : " Log in",
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // AUTH LOGIC
  // ─────────────────────────────────────────────
  Future<void> _handleAuth() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    try {
      if (isLogin) {
        // ───────── LOGIN ─────────
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user!;

        // 🔐 Initialize master key (Option A)
        await UserCryptoState.initializeForUser(
          userId: user.uid,
          password: password,
        );

        final hasUsername = await _userHasUsername(user.uid);
        _navigateAccordingToUsername(hasUsername);
      } else {
        // ───────── SIGN UP ─────────
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user!;
        final encryptionSalt = _generateEncryptionSalt();
        final usernameBase = user.email!.split('@')[0];
        final displayName = _capitalize(usernameBase);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'displayName': displayName,
          'email': user.email,
          'email_lowercase': email,
          'bio': '',
          'photoUrl': null,
          'encryptionSalt': encryptionSalt,
          'createdAt': Timestamp.now(),
          'darkMode': false,
        }, SetOptions(merge: true));

        // 🔐 IMPORTANT: initialize master key immediately after signup
        await UserCryptoState.initializeForUser(
          userId: user.uid,
          password: password,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ChooseUsernameScreen(),
          ),
        );
        return;
      }

      // Update last login
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set(
          {'lastLogin': Timestamp.now()},
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      _showFieldErrors(emailMsg: e.toString());
    }
  }

  Future<bool> _userHasUsername(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return (doc.data()?['username'] ?? '').toString().isNotEmpty;
  }

  Future<void> _navigateAccordingToUsername(bool hasUsername) async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            hasUsername ? const HomeScreen() : const ChooseUsernameScreen(),
      ),
    );
  }
}
