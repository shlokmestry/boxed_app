import 'package:boxed_app/screens/home_screen.dart';
import 'package:boxed_app/screens/profile_screen.dart';
import 'package:boxed_app/screens/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/login_signup.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initialize the plugin for showing notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Setup local notifications
void setupFlutterNotifications() {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

/// Show notification when message received in foreground
void showNotification(RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

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

/// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📩 Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notification setup
  setupFlutterNotifications();

  // Foreground listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message in foreground!');
    print("Title: ${message.notification?.title}");
    print("Body: ${message.notification?.body}");
    print("Data payload: ${message.data}");
    showNotification(message); // Manually show notification
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _getOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_seen') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      title: 'Boxed',
      home: FutureBuilder<bool>(
        future: _getOnboardingSeen(),
        builder: (context, onboardingSnapshot) {
          if (!onboardingSnapshot.hasData) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final onboardingSeen = onboardingSnapshot.data!;
          if (!onboardingSeen) {
            return const SplashScreen();
          }
          // Onboarding seen, now listen to auth state
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final user = snapshot.data;
              if (user != null) {
                return const HomeScreen();
              } else {
                return const LoginSignup();
              }
            },
          );
        },
      ),
    );
  }
}
