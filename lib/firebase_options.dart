import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD0bjN5sdR5dP6_6T7rB5VNcll_0fmlUKo',
    appId: '1:790092689160:web:a1aa026894435ff8ef06bd',
    messagingSenderId: '790092689160',
    projectId: 'growlens-2b6b2',
    authDomain: 'growlens-2b6b2.firebaseapp.com',
    databaseURL: 'https://growlens-2b6b2-default-rtdb.firebaseio.com',
    storageBucket: 'growlens-2b6b2.firebasestorage.app',
    measurementId: 'G-XSE55NVFVS',
  );

  // Web config

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCZY_6dmMMPgy0rm-Q3t3bPn7P6cIGi4iQ',
    appId: '1:790092689160:android:b8ecc9aad979fbe5ef06bd',
    messagingSenderId: '790092689160',
    projectId: 'growlens-2b6b2',
    databaseURL: 'https://growlens-2b6b2-default-rtdb.firebaseio.com',
    storageBucket: 'growlens-2b6b2.firebasestorage.app',
  );

  // Android config

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBbl2NdGmDBIlc4c9NsMWcm416VmxfDGzI',
    appId: '1:790092689160:ios:fe9ca6cfdb3e2ccdef06bd',
    messagingSenderId: '790092689160',
    projectId: 'growlens-2b6b2',
    databaseURL: 'https://growlens-2b6b2-default-rtdb.firebaseio.com',
    storageBucket: 'growlens-2b6b2.firebasestorage.app',
    iosBundleId: 'com.example.firstflutterproject',
  );

  // iOS config (optional)
}