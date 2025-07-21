import 'package:boxed_app/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';


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

  Future<void> _signInWithGoogle() async {
  try {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCred.user;

    if (user != null) {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        final now = Timestamp.now();
        await docRef.set({
          'firstName': user.displayName?.split(' ').first ?? '',
          'lastName': user.displayName?.split(' ').last ?? '',
          'username': user.email?.split('@').first ?? '',
          'email': user.email,
          'photoUrl': user.photoURL,
          'bio': '',
          'createdAt': now,
          'darkMode': false,
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Google sign-in failed: $e')),
    );
  }
}


Future<void> _signInWithApple() async {
  try {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCred = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
    final user = userCred.user;

    if (user != null) {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        final now = Timestamp.now();
        await docRef.set({
          'firstName': appleCredential.givenName ?? '',
          'lastName': appleCredential.familyName ?? '',
          'username': user.email?.split('@').first ?? 'apple_user',
          'email': user.email,
          'photoUrl': null,
          'bio': '',
          'createdAt': now,
          'darkMode': false,
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Apple sign-in failed: $e')),
    );
  }
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
                      emailMsg: email.isEmpty ? 'Please enter your email.' : null,
                      passwordMsg: password.isEmpty ? 'Please enter your password.' : null,
                    );
                    return;
                  }

                  try {
                    if (isLogin) {
                      final credential = await FirebaseAuth.instance
                          .signInWithEmailAndPassword(
                        email: email,
                        password: password,
                      );

                      final user = credential.user;
                      if (user != null) {
                        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
                        final snapshot = await userDoc.get();

                        if (!snapshot.exists) {
                          final now = Timestamp.now();
                          final username = user.email!.split('@')[0];
                          await userDoc.set({
                            'username': username,
                            'email': user.email,
                            'createdAt': now,
                            'displayName': _capitalize(username),
                            'bio': '',
                            'photoUrl': null,
                            'darkMode': false,
                          });
                        }

                        await userDoc.set({
                          'lastLogin': Timestamp.now(),
                        }, SetOptions(merge: true));
                      }

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
                        final username = user.email!.split('@')[0];

                        String displayName = '';
                        String firstName = '';
                        String lastName = '';
                        if (username.contains('.')) {
                          final parts = username.split('.');
                          firstName = parts[0];
                          lastName = parts.length > 1 ? parts[1] : '';
                          displayName = '${_capitalize(firstName)} ${_capitalize(lastName)}';
                        } else {
                          firstName = username;
                          displayName = _capitalize(username);
                        }

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set({
                          'firstName': _capitalize(firstName),
                          'lastName': _capitalize(lastName),
                          'displayName': displayName,
                          'email': user.email,
                          'email_lowercase': user.email!.toLowerCase(),
                          'photoUrl': null,
                          'bio': '',
                          'createdAt': now,
                          'darkMode': false,
                        }, SetOptions(merge: true));

                        // ✅ Redirect to choose username screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ChooseUsernameScreen()),
                        );
                      }
                    }
                  } on FirebaseAuthException catch (e) {
                    String message;
                    switch (e.code) {
                      case 'user-not-found':
                        message = 'This email’s a stranger to us. Want to sign up instead?';
                        break;
                      case 'wrong-password':
                      case 'invalid-credential':
                        message = 'That password wasn’t quite right — give it another shot';
                        break;
                      case 'invalid-email':
                        message = 'We love creativity, but that’s not a valid email';
                        break;
                      case 'email-already-in-use':
                        message = 'Looks like you’ve already joined the Boxed club. Welcome back?';
                        break;
                      case 'weak-password':
                        message = 'Your password needs a protein shake — at least 6 characters';
                        break;
                      default:
                        message = 'Authentication error: ${e.message}';
                    }

                    if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                      _showFieldErrors(passwordMsg: message);
                    } else if (e.code == 'user-not-found' ||
                        e.code == 'invalid-email' ||
                        e.code == 'email-already-in-use') {
                      _showFieldErrors(emailMsg: message);
                    } else {
                      _showFieldErrors(emailMsg: message);
                    }
                  } catch (e) {
                    print('Login/SignUp error: $e');
                    _showFieldErrors(emailMsg: 'An unexpected error occurred. Please try again.');
                  }
                },
              ),

              const SizedBox(height: 20),
Row(children: <Widget>[
  Expanded(child: Divider(color: Colors.grey)),
  const Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: Text('or', style: TextStyle(color: Colors.grey)),
  ),
  Expanded(child: Divider(color: Colors.grey)),
]),
const SizedBox(height: 16),

if (Platform.isIOS)
  Column(
    children: [
      SizedBox(
  width: double.infinity,
  height: 50,
  child: OutlinedButton.icon(
    onPressed: _signInWithApple,
    icon: const Icon(Icons.apple, color: Colors.black),
    label: const Text(
      "Continue with Apple",
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      side: const BorderSide(color: Colors.transparent),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
),

      SizedBox(height: 10),
      _googleButton(),
    ],
  )
else
  _googleButton(),

              
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
Widget _googleButton() {
  return SizedBox(
    width: double.infinity, 
    height: 50,             
    child: OutlinedButton.icon(
      onPressed: _signInWithGoogle,
      icon: Image.asset('assets/google_icon.png', height: 24), 
      label: const Text(
        "Continue with Google",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), 
        ),
      ),
    ),
  );
}


}
