import 'package:boxed_app/providers/theme_provider.dart';
import 'package:boxed_app/features/capsules/screens/home_screen.dart';
import 'package:boxed_app/features/Settings/Misc/splash_screen.dart';
import 'package:boxed_app/features/auth/choose_username_screen.dart';
import 'package:boxed_app/features/auth/login_signup.dart';
import 'package:boxed_app/features/capsules/state/capsule_controller.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:boxed_app/core/theme/app_theme.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void setupFlutterNotifications() {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();

  const initializationSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void showNotification(RemoteMessage message) {
  final notification = message.notification;
  final android = message.notification?.android;

  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('📩 Background message received: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen(showNotification);

  setupFlutterNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CapsuleController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _getOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_seen') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Boxed',
      themeMode: themeProvider.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      
      // ⭐ SIMPLIFIED: No auth listener - let LoginSignup handle navigation
      home: FutureBuilder<bool>(
        future: _getOnboardingSeen(),
        builder: (context, onboardingSnapshot) {
          if (onboardingSnapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (onboardingSnapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Failed to load app state')),
            );
          }

          final onboardingSeen = onboardingSnapshot.data ?? false;

          if (!onboardingSeen) {
            return const SplashScreen();
          }

          // ⭐ Check current user state once on app start
          final currentUser = FirebaseAuth.instance.currentUser;
          
          if (currentUser == null) {
            // Not logged in
            return const LoginSignup();
          }

          // User is logged in - check crypto and username
          return FutureBuilder<void>(
            future: UserCryptoState.initialize(currentUser.uid),
            builder: (context, cryptoSnapshot) {
              if (cryptoSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // If crypto fails, force re-login
              if (cryptoSnapshot.hasError) {
                debugPrint('🔴 Crypto initialization failed, forcing re-login');
                return const LoginSignup();
              }

              // Check username
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get(),
                builder: (context, userDocSnapshot) {
                  if (userDocSnapshot.connectionState != ConnectionState.done) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (userDocSnapshot.hasError) {
                    debugPrint('🔴 Failed to load user doc: ${userDocSnapshot.error}');
                    return const LoginSignup();
                  }

                  final data = userDocSnapshot.data?.data() as Map<String, dynamic>?;
                  final hasUsername = data != null &&
                      data['username'] != null &&
                      data['username'].toString().trim().isNotEmpty;

                  return hasUsername 
                      ? const HomeScreen() 
                      : const ChooseUsernameScreen();
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ⭐ These functions are now no-ops since we removed the auth listener
// Keeping them for compatibility with login_signup.dart
void disableAuthNavigation() {
  debugPrint('🔒 Auth navigation disabled (no-op in simplified version)');
}

void enableAuthNavigation() {
  debugPrint('🔓 Auth navigation enabled (no-op in simplified version)');
}