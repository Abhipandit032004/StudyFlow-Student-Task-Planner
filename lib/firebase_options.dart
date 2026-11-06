// Template Firebase options. Recommended: generate the real file with FlutterFire CLI.
// Run `flutterfire configure` from the project root. It will generate platform-specific
// Firebase options; replace this template with the generated file.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      case TargetPlatform.macOS: return macos;
      case TargetPlatform.windows: return windows;
      case TargetPlatform.linux: return linux;
      default: throw UnsupportedError('StudyFlow does not support this platform yet.');
    }
  }

  // Placeholder values intentionally cause Firebase initialization to fail until configured.

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCL-0jMtFunEviRNkteXEhy8C98B4ptBvM',
    appId: '1:409573071567:web:c3b12ca40961b356de35ba',
    messagingSenderId: '409573071567',
    projectId: 'studyflow-f88cf',
    authDomain: 'studyflow-f88cf.firebaseapp.com',
    storageBucket: 'studyflow-f88cf.firebasestorage.app',
    measurementId: 'G-0ME0H14N4W',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVyfGtba5-Kj8XN2O-JIfWIwJkeIm8I14',
    appId: '1:409573071567:android:f968ea43483676cfde35ba',
    messagingSenderId: '409573071567',
    projectId: 'studyflow-f88cf',
    storageBucket: 'studyflow-f88cf.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(apiKey: 'YOUR_IOS_API_KEY', appId: 'YOUR_IOS_APP_ID', messagingSenderId: 'YOUR_MESSAGING_SENDER_ID', projectId: 'YOUR_FIREBASE_PROJECT_ID', iosBundleId: 'com.example.studentTaskPlanner');
  static const FirebaseOptions macos = FirebaseOptions(apiKey: 'YOUR_MACOS_API_KEY', appId: 'YOUR_MACOS_APP_ID', messagingSenderId: 'YOUR_MESSAGING_SENDER_ID', projectId: 'YOUR_FIREBASE_PROJECT_ID', iosBundleId: 'com.example.studentTaskPlanner');
  static const FirebaseOptions windows = FirebaseOptions(apiKey: 'YOUR_WINDOWS_API_KEY', appId: 'YOUR_WINDOWS_APP_ID', messagingSenderId: 'YOUR_MESSAGING_SENDER_ID', projectId: 'YOUR_FIREBASE_PROJECT_ID', authDomain: 'YOUR_FIREBASE_PROJECT_ID.firebaseapp.com');
  static const FirebaseOptions linux = FirebaseOptions(apiKey: 'YOUR_LINUX_API_KEY', appId: 'YOUR_LINUX_APP_ID', messagingSenderId: 'YOUR_MESSAGING_SENDER_ID', projectId: 'YOUR_FIREBASE_PROJECT_ID', authDomain: 'YOUR_FIREBASE_PROJECT_ID.firebaseapp.com');
}
