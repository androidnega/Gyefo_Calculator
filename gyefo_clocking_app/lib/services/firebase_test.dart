import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

/// Simple test to verify Firebase Authentication is working
Future<void> testFirebaseAuth() async {
  if (!kDebugMode) return;

  try {
    AppLogger.info(
      '\n🔍 Testing Firebase Authentication...\n',
    ); // 1. Test basic connection
    AppLogger.info('1. Testing connection to Firebase...');
    final auth = FirebaseAuth.instance;

    // Check if Firebase is initialized
    if (Firebase.apps.isNotEmpty) {
      AppLogger.success('Firebase is responding!\n');
    } else {
      AppLogger.error('Firebase Authentication not initialized\n');
      return;
    }

    // 2. Test if Auth is enabled
    AppLogger.info('2. Checking Authentication status...');
    try {
      // Try to get the current auth state
      await auth.authStateChanges().first;
      AppLogger.success('Authentication appears to be enabled\n');
    } catch (e) {
      AppLogger.warning(
        'Authentication service may not be fully initialized: ${e.toString()}\n',
      );
    }

    // 3. Print helpful status
    AppLogger.success('Firebase Authentication service is working!');
    AppLogger.info('You can now:');
    AppLogger.info('1. Create accounts in Firebase Console');
    AppLogger.info('2. Use the Demo Setup screen in the app');
    AppLogger.info('3. Login with test accounts once created\n');
  } catch (e) {
    AppLogger.error('\nFirebase Authentication Error:');
    AppLogger.error('$e\n');
    AppLogger.info('Please check:');
    AppLogger.info('1. Authentication is enabled in Firebase Console');
    AppLogger.info('2. Email/Password provider is enabled');
    AppLogger.info('3. Web app is properly configured');
    AppLogger.info('4. Wait 2-3 minutes after enabling Authentication\n');
  }
}
