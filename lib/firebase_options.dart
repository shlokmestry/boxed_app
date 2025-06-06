// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );

    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBVbZF62I6QvfNNZ-eyuMtI4Ibjj4ZHDe0',
    appId: '1:734931807048:web:8f6d37f5785f99a1eda17d',
    messagingSenderId: '734931807048',
    projectId: 'boxed-562ab',
    authDomain: 'boxed-562ab.firebaseapp.com',
    storageBucket: 'boxed-562ab.firebasestorage.app',
    measurementId: 'G-B0Q6E6Y8W8',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBuQ2OWLDCT8uYyOqGrWTdRLiKKnaGjtuI',
    appId: '1:734931807048:ios:1c938744cec0eeededa17d',
    messagingSenderId: '734931807048',
    projectId: 'boxed-562ab',
    storageBucket: 'boxed-562ab.firebasestorage.app',
    iosClientId: '734931807048-h8rgum8hvs55j90ah0es8ficuha30na5.apps.googleusercontent.com',
    iosBundleId: 'com.example.boxedApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBVbZF62I6QvfNNZ-eyuMtI4Ibjj4ZHDe0',
    appId: '1:734931807048:web:4948a92bfdaaba25eda17d',
    messagingSenderId: '734931807048',
    projectId: 'boxed-562ab',
    authDomain: 'boxed-562ab.firebaseapp.com',
    storageBucket: 'boxed-562ab.firebasestorage.app',
    measurementId: 'G-NBL2HRPL24',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBuQ2OWLDCT8uYyOqGrWTdRLiKKnaGjtuI',
    appId: '1:734931807048:ios:1c938744cec0eeededa17d',
    messagingSenderId: '734931807048',
    projectId: 'boxed-562ab',
    storageBucket: 'boxed-562ab.firebasestorage.app',
    iosClientId: '734931807048-h8rgum8hvs55j90ah0es8ficuha30na5.apps.googleusercontent.com',
    iosBundleId: 'com.example.boxedApp',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyASYwmD01nIgMdsX0A1usgUFkKm03yGeRc',
    appId: '1:734931807048:android:1eb9d8a211327413eda17d',
    messagingSenderId: '734931807048',
    projectId: 'boxed-562ab',
    storageBucket: 'boxed-562ab.firebasestorage.app',
  );

}