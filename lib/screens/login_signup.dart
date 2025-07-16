import 'package:boxed_app/widgets/buttons.dart';
import 'package:boxed_app/services/encryption_service.dart';
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
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Notification permission: ${settings.authorizationStatus}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Welcome to Boxed',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Your memories, waiting patiently.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: emailController,
                onChanged: (_) {
                  if (emailError != null) {
                    setState(() => emailError = null);
                  }
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: Colors.white70),
                  errorText: emailError,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                onChanged: (_) {
                  if (passwordError != null) {
                    setState(() => passwordError = null);
                  }
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.white70),
                  errorText: passwordError,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              Buttons(
                label: isLogin ? 'Log In' : 'Sign Up',
                onPressed: () async {
                  final email = emailController.text.trim().toLowerCase();
                  final password = passwordController.text.trim();

                  if (email.isEmpty || password.isEmpty) {
                    _showFieldErrors(
                      emailMsg:
                          email.isEmpty ? 'Please enter your email.' : null,
                      passwordMsg:
                          password.isEmpty ? 'Please enter your password.' : null,
                    );
                    return;
                  }

                  try {
                    if (isLogin) {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: email,
                        password: password,
                      );
                    } else {
                      final credential = await FirebaseAuth.instance
                          .createUserWithEmailAndPassword(
                        email: email,
                        password: password,
                      );

                      final user = credential.user;

                      if (user != null) {
                        final now = Timestamp.now();

                        // ✅ Generate RSA keypair for the user (only on signup)
                        await EncryptionService.generateAndStoreKeyPair(user.uid);

                        // ✅ Save user data in Firestore
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set({
                          'firstName': '',
                          'lastName': '',
                          'username': user.email!.split('@')[0],
                          'email': user.email,
                          'photoUrl': null,
                          'bio': '',
                          'createdAt': now,
                          'darkMode': false,
                        }, SetOptions(merge: true));
                      }
                    }

                    // ✅ Last login timestamp
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .set({
                        'lastLogin': Timestamp.now(),
                      }, SetOptions(merge: true));
                    }

                    // ✅ Navigate to home
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  } on FirebaseAuthException catch (e) {
                    String message;
                    switch (e.code) {
                      case 'user-not-found':
                        message =
                            'This email’s a stranger to us. Want to sign up instead?';
                        break;
                      case 'wrong-password':
                      case 'invalid-credential':
                        message =
                            'That password wasn’t quite right — give it another shot';
                        break;
                      case 'invalid-email':
                        message =
                            'We love creativity, but that’s not a valid email';
                        break;
                      case 'email-already-in-use':
                        message =
                            'Looks like you’ve already joined the Boxed club. Welcome back?';
                        break;
                      case 'weak-password':
                        message =
                            'Your password needs a protein shake — at least 6 characters';
                        break;
                      default:
                        message = 'Authentication error: ${e.message}';
                    }

                    if (e.code == 'wrong-password' ||
                        e.code == 'invalid-credential') {
                      _showFieldErrors(passwordMsg: message);
                    } else if (e.code == 'user-not-found' ||
                        e.code == 'invalid-email' ||
                        e.code == 'email-already-in-use') {
                      _showFieldErrors(emailMsg: message);
                    } else {
                      _showFieldErrors(emailMsg: message);
                    }
                  } catch (e) {
                    _showFieldErrors(
                      emailMsg: 'An unexpected error occurred. Please try again.',
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLogin
                        ? "Don't have an account?"
                        : "Already have an account?",
                    style: const TextStyle(color: Colors.white),
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
                      style: const TextStyle(
                        color: Colors.white,
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
}
