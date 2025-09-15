// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web Firebase config
      return const FirebaseOptions(
        apiKey: "AIzaSyBBDr1oyVWZVXQu12CsZgK5TPigbqVrZ9A",
        authDomain: "swcaiagent007.firebaseapp.com",
        projectId: "swcaiagent007",
        storageBucket: "swcaiagent007.firebasestorage.app",
        messagingSenderId: "4143079453",
        appId: "1:4143079453:web:25facd1ae451436ad266f4",
        measurementId: "G-DDCKR5DLCW",
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // TODO: Replace with your Android config from Firebase Console
        return const FirebaseOptions(
          apiKey: "ANDROID_API_KEY",
          appId: "ANDROID_APP_ID",
          messagingSenderId: "ANDROID_MESSAGING_SENDER_ID",
          projectId: "swcaiagent007",
          storageBucket: "swcaiagent007.firebasestorage.app",
        );
      case TargetPlatform.iOS:
        // TODO: Replace with your iOS config from Firebase Console
        return const FirebaseOptions(
          apiKey: "IOS_API_KEY",
          appId: "IOS_APP_ID",
          messagingSenderId: "IOS_MESSAGING_SENDER_ID",
          projectId: "swcaiagent007",
          storageBucket: "swcaiagent007.firebasestorage.app",
          iosClientId: "IOS_CLIENT_ID",
          iosBundleId: "IOS_BUNDLE_ID",
        );
      case TargetPlatform.macOS:
        return const FirebaseOptions(
          apiKey: "MACOS_API_KEY",
          appId: "MACOS_APP_ID",
          messagingSenderId: "MACOS_MESSAGING_SENDER_ID",
          projectId: "swcaiagent007",
          storageBucket: "swcaiagent007.firebasestorage.app",
          iosClientId: "MACOS_CLIENT_ID",
          iosBundleId: "MACOS_BUNDLE_ID",
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
