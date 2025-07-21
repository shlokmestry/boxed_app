import 'package:boxed_app/widgets/buttons.dart';
import 'package:boxed_app/screens/choose_username_screen.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _logFcmToken();
  }

  void _requestNotificationPermission() async {
    await FirebaseMessaging.instance.requestPermission();
  }

  void _logFcmToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print('📱 FCM Token: $token');
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

              /// Email Field
              TextField(
                controller: emailController,
                onChanged: (_) {
                  if (emailError != null) setState(() => emailError = null);
                },
                decoration: InputDecoration(
                  hintText: 'Email',
                  errorText: emailError,
                  hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: colorScheme.onBackground),
              ),
              const SizedBox(height: 10),

              /// Password Field
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                onChanged: (_) {
                  if (passwordError != null) setState(() => passwordError = null);
                },
                decoration: InputDecoration(
                  hintText: 'Password',
                  errorText: passwordError,
                  hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                  filled: true,
                  fillColor: colorScheme.surface,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: colorScheme.onBackground),
              ),
              const SizedBox(height: 20),

              /// Auth Button
              Buttons(
                label: isLogin ? 'Log In' : 'Sign Up',
                onPressed: _handleAuth,
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin ? "Don't have an account?" : "Already have an account?",
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onBackground),
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

  Future<void> _handleAuth() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showFieldErrors(
        emailMsg: email.isEmpty ? 'Please enter your email.' : null,
        passwordMsg: password.isEmpty ? 'Please enter your password.' : null,
      );
      return;
    }

    try {
      if (isLogin) {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final uid = credential.user!.uid;
        final hasUsername = await _userHasUsername(uid);
        _navigateAccordingToUsername(hasUsername);
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        final user = credential.user;

        if (user != null) {
          final usernameBase = user.email!.split('@')[0];
          String firstName = '';
          String lastName = '';
          String displayName;

          if (usernameBase.contains('.')) {
            final parts = usernameBase.split('.');
            firstName = parts[0];
            lastName = parts.length > 1 ? parts[1] : '';
            displayName = '${_capitalize(firstName)} ${_capitalize(lastName)}';
          } else {
            firstName = usernameBase;
            displayName = _capitalize(usernameBase);
          }

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'firstName': _capitalize(firstName),
            'lastName': _capitalize(lastName),
            'displayName': displayName,
            'email': user.email,
            'email_lowercase': email,
            'photoUrl': null,
            'bio': '',
            'createdAt': Timestamp.now(),
            'darkMode': false,
          }, SetOptions(merge: true));

          // Immediately direct all signups to ChooseUsernameScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChooseUsernameScreen()),
          );
          return; // Stop further logic
        }
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set(
          {'lastLogin': Timestamp.now()},
          SetOptions(merge: true),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = "This email’s a stranger to us. Want to sign up instead?";
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = "That password wasn’t quite right — give it another shot";
          break;
        case 'invalid-email':
          message = "We love creativity, but that’s not a valid email";
          break;
        case 'email-already-in-use':
          message = "You've already joined Boxed! Tap 'Log In' to enter the vault.";
          break;
        case 'weak-password':
          message = "Make that password stronger (6+ characters)";
          break;
        default:
          message = 'Authentication error: ${e.message}';
      }

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showFieldErrors(passwordMsg: message);
      } else {
        _showFieldErrors(emailMsg: message);
      }
    } catch (e) {
      _showFieldErrors(emailMsg: 'Unexpected error — please try again.');
    }
  }

  Future<bool> _userHasUsername(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    final username = data?['username'];
    return username != null && username.toString().trim().isNotEmpty;
  }

  Future<void> _navigateAccordingToUsername(bool hasUsername) async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => hasUsername ? const HomeScreen() : const ChooseUsernameScreen(),
      ),
    );
  }
}
