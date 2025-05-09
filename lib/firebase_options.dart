import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web options
      return const FirebaseOptions(
        apiKey: 'AIzaSyDzkdOLlvclZoC7WCh7kP8Hg7AeN4MAgWg',
        appId:
            '1:36267912737:web:e1751181d66e4435b67d60', // Note: this is a placeholder, you may need to update it
        messagingSenderId: '36267912737',
        projectId: 'fitly-5651e',
        storageBucket: 'fitly-5651e.firebasestorage.app',
        authDomain: 'fitly-5651e.firebaseapp.com', // Required for web
      );
    } else {
      // iOS/Android options
      return const FirebaseOptions(
        apiKey: 'AIzaSyDzkdOLlvclZoC7WCh7kP8Hg7AeN4MAgWg',
        appId: '1:36267912737:ios:e1751181d66e4435b67d60',
        messagingSenderId: '36267912737',
        projectId: 'fitly-5651e',
        storageBucket: 'fitly-5651e.firebasestorage.app',
      );
    }
  }
}

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
