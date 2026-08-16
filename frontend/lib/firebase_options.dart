// GENERATED FILE PLACEHOLDER — replace by running `flutterfire configure`.
//
// This file normally gets generated automatically by the FlutterFire CLI,
// which reads your actual Firebase project and fills in real API keys/IDs
// for each platform you target. The values below are placeholders so the
// project compiles; Firebase calls will fail with an auth/configuration
// error until you replace this file with the real generated one.
//
// To generate the real file:
//   1. npm install -g firebase-tools   (if you don't have the Firebase CLI)
//   2. firebase login
//   3. dart pub global activate flutterfire_cli
//   4. flutterfire configure
//        -> select your Firebase project (or create one)
//        -> select the platforms you want (web/android/ios)
//   This overwrites this exact file with real values and registers each
//   platform's app in your Firebase project automatically.

import "package:firebase_core/firebase_core.dart" show FirebaseOptions;
import "package:flutter/foundation.dart" show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          "DefaultFirebaseOptions have not been configured for this platform. "
          "Run `flutterfire configure` to generate real values.",
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCmxZtf5o2X70TIIUtuFl5lxBEU8wi3WBI',
    appId: '1:979846272416:web:f968830389cf5fcc3f80c5',
    messagingSenderId: '979846272416',
    projectId: 'tecron-v1',
    authDomain: 'tecron-v1.firebaseapp.com',
    storageBucket: 'tecron-v1.firebasestorage.app',
    measurementId: 'G-BXFBDDKXY8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBPKqC_HgweoyYER9dlN8g9J5JNUKvK3b4',
    appId: '1:979846272416:android:74e458a8f14c007d3f80c5',
    messagingSenderId: '979846272416',
    projectId: 'tecron-v1',
    storageBucket: 'tecron-v1.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "REPLACE_ME",
    appId: "REPLACE_ME",
    messagingSenderId: "REPLACE_ME",
    projectId: "REPLACE_ME",
    storageBucket: "REPLACE_ME.appspot.com",
    iosBundleId: "REPLACE_ME",
  );
}
