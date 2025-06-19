// SECURE Firebase Options - Uses Environment Variables
// This file replaces the original firebase_options.dart with secure environment-based configuration
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import '../config/env_config.dart';

/// Secure [FirebaseOptions] that uses environment variables instead of hardcoded values
///
/// Example usage:
/// ```dart
/// import 'firebase_options_secure.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: SecureFirebaseOptions.currentPlatform,
/// );
/// ```
class SecureFirebaseOptions {
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
        throw UnsupportedError(
          'SecureFirebaseOptions have not been configured for windows',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'SecureFirebaseOptions have not been configured for linux',
        );
      default:
        throw UnsupportedError(
          'SecureFirebaseOptions are not supported for this platform.',
        );
    }
  }
  static FirebaseOptions get web {
    // Validate configuration before creating options
    if (!EnvConfig.validateConfig()) {
      if (kIsWeb) {
        // For web, we can still try to initialize with whatever we have
        debugPrint('Warning: Incomplete Firebase web configuration detected');
      }
    }
    
    return FirebaseOptions(
      apiKey: EnvConfig.firebaseApiKeyWeb,
      appId: EnvConfig.firebaseAppIdWeb,
      messagingSenderId: EnvConfig.firebaseMessagingSenderId,
      projectId: EnvConfig.firebaseProjectId,
      authDomain: EnvConfig.firebaseAuthDomain,
      storageBucket: EnvConfig.firebaseStorageBucket,
    );
  }

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: EnvConfig.firebaseApiKeyAndroid,
    appId: EnvConfig.firebaseAppIdAndroid,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    storageBucket: EnvConfig.firebaseStorageBucket,
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: EnvConfig.firebaseApiKeyIos,
    appId: EnvConfig.firebaseAppIdIos,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    storageBucket: EnvConfig.firebaseStorageBucket,
    iosBundleId: 'com.example.gyefoClockingApp',
  );

  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: EnvConfig.firebaseApiKeyIos,
    appId: EnvConfig.firebaseAppIdIos,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    storageBucket: EnvConfig.firebaseStorageBucket,
    iosBundleId: 'com.example.gyefoClockingApp',
  );
}
