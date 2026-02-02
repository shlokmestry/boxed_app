import 'dart:math';

import 'package:boxed_app/core/widgets/buttons.dart';
import 'package:boxed_app/features/auth/choose_username_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../capsules/screens/home_screen.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'forgot_password_screen.dart';

// ⭐ Import the main.dart helpers
import 'package:boxed_app/main.dart' show disableAuthNavigation, enableAuthNavigation;

class LoginSignup extends StatefulWidget {
  const LoginSignup({super.key});

  @override
  State<LoginSignup> createState() => _LoginSignupState();
}

class _LoginSignupState extends State<LoginSignup> {
  bool isLogin = true;
  bool obscurePassword = true;
  bool _isLoading = false;

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
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      // Only try to get FCM token on real devices, not simulators
      if (mounted) {
        final token = await FirebaseMessaging.instance.getToken();
        debugPrint('📱 FCM Token: $token');
      }
    } catch (e) {
      // Ignore FCM errors in simulator
      debugPrint('⚠️ FCM not available (likely simulator): $e');
    }
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
                  isLogin ? 'Welcome back to Boxed' : 'Welcome to Boxed',
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
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
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
                enabled: !_isLoading,
                autocorrect: false,
                enableSuggestions: false,
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

              const SizedBox(height: 6),

              // Forgot password
              if (isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Auth Button
              Buttons(
                label: isLogin ? 'Log In' : 'Sign Up',
                onPressed: _isLoading ? null : _handleAuth,
                isLoading: _isLoading,
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
                    onTap: _isLoading
                        ? null
                        : () {
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

    // Validation
    if (email.isEmpty) {
      _showFieldErrors(emailMsg: 'Please enter your email');
      return;
    }
    if (!email.contains('@')) {
      _showFieldErrors(emailMsg: 'Please enter a valid email');
      return;
    }
    if (password.isEmpty) {
      _showFieldErrors(passwordMsg: 'Please enter your password');
      return;
    }
    if (password.length < 6) {
      _showFieldErrors(
          passwordMsg: 'Password must be at least 6 characters');
      return;
    }

    // Store the current mode to prevent state changes during async operations
    final currentMode = isLogin;
    
    setState(() => _isLoading = true);

    try {
      if (currentMode) {
        // ─────────────────────────────────────────────
        // LOGIN FLOW
        // ─────────────────────────────────────────────
        debugPrint('🟢 Starting login process for: $email');
        
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user!;
        debugPrint('🟢 User logged in: ${user.uid}');
        
        // Initialize encryption
        await UserCryptoState.initializeForUser(
          userId: user.uid,
          password: password,
        );

        debugPrint('🟢 Crypto initialized');

        // Check if user has username
        final hasUsername = await _userHasUsername(user.uid);
        debugPrint('🟢 Has username: $hasUsername');
        
        if (!mounted) {
          debugPrint('🔴 Widget not mounted, cannot navigate');
          return;
        }
        
        // Clear loading state before navigation
        setState(() => _isLoading = false);
        
        _navigateAccordingToUsername(hasUsername);
        return; // Exit early to prevent error handling blocks from running
      } else {
        // ─────────────────────────────────────────────
        // SIGNUP FLOW
        // ─────────────────────────────────────────────
        debugPrint('🟢 Starting signup process for: $email');
        
        // ⭐ CRITICAL FIX: Disable automatic auth navigation
        disableAuthNavigation();
        
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        debugPrint('🟢 User created in Firebase Auth: ${credential.user!.uid}');

        final user = credential.user!;
        final encryptionSalt = _generateEncryptionSalt();
        final usernameBase = user.email!.split('@')[0];

        // Create user document in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'displayName': _capitalize(usernameBase),
          'email': user.email,
          'email_lowercase': email,
          'bio': '',
          'photoUrl': null,
          'encryptionSalt': encryptionSalt,
          'createdAt': Timestamp.now(),
          'darkMode': false,
          // Note: username will be set in ChooseUsernameScreen
        }, SetOptions(merge: true));

        debugPrint('🟢 User document created in Firestore');

        // Initialize encryption
        await UserCryptoState.initializeForUser(
          userId: user.uid,
          password: password,
        );

        debugPrint('🟢 Crypto initialized, navigating to username screen');

        if (!mounted) {
          debugPrint('🔴 Widget not mounted, cannot navigate');
          enableAuthNavigation(); // Re-enable before exiting
          return;
        }

        // Clear loading state before navigation
        setState(() => _isLoading = false);

        // Navigate to username selection
        await Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const ChooseUsernameScreen(),
          ),
          (route) => false, // Remove all previous routes
        );
        
        debugPrint('🟢 Navigation to username screen complete');
        
        // ⭐ Re-enable auth navigation after successful navigation
        enableAuthNavigation();
        return; // Exit early to prevent error handling blocks from running
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 Auth error: ${e.code} - ${e.message}');
      
      // Re-enable auth navigation on error
      enableAuthNavigation();
      
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Please log in.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use a stronger password.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed. Please try again.';
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          emailError = errorMessage;
          passwordError = null;
        });
      }
    } catch (e) {
      debugPrint('🔴 Unexpected error: $e');
      
      // Re-enable auth navigation on error
      enableAuthNavigation();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          emailError = 'An unexpected error occurred. Please try again.';
          passwordError = null;
        });
      }
    }
  }

  Future<bool> _userHasUsername(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (!doc.exists) return false;
      
      final username = doc.data()?['username'];
      return username != null && username.toString().trim().isNotEmpty;
    } catch (e) {
      debugPrint('🔴 Error checking username: $e');
      return false;
    }
  }

  void _navigateAccordingToUsername(bool hasUsername) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            hasUsername ? const HomeScreen() : const ChooseUsernameScreen(),
      ),
    );
  }
}