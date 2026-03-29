import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return android; // placeholder — add iOS config later
      case TargetPlatform.windows:
        return android; // placeholder — add Windows config later
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDfQXHv4WJcEowgNFicDm9UTwftHmbcUUo',
    appId: '1:47440299911:android:799c592d9876ce6df1b522',
    messagingSenderId: '47440299911',
    projectId: 'hire-horizon-c47c7',
    storageBucket: 'hire-horizon-c47c7.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDQC6khvhhjynEpNUBXvI1J7K1hdWf30a4',
    appId: '1:47440299911:web:3117e15e3e00d3e6f1b522',
    messagingSenderId: '47440299911',
    projectId: 'hire-horizon-c47c7',
    storageBucket: 'hire-horizon-c47c7.firebasestorage.app',
    authDomain: 'hire-horizon-c47c7.firebaseapp.com',
    measurementId: 'G-XF5Y0CL1DH',
  );
}
