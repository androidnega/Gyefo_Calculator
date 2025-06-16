import 'package:flutter/foundation.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class ManualAccountCreator {
  /// Instructions for manually creating demo accounts in Firebase Console
  static void printSetupInstructions() {
    if (!kDebugMode) return;

    AppLogger.info('\n=== MANUAL DEMO ACCOUNT SETUP INSTRUCTIONS ===\n');
    AppLogger.info(
      'Since automatic account creation may have issues, follow these steps:',
    );
    AppLogger.info('');
    AppLogger.info(
      '1. Open Firebase Console: https://console.firebase.google.com/',
    );
    AppLogger.info('2. Select your Gyefo Clocking App project');
    AppLogger.info('3. Navigate to Authentication > Users');
    AppLogger.info('4. Click "Add user" and create these accounts:');
    AppLogger.info('');

    AppLogger.info('   📧 MANAGER ACCOUNT:');
    AppLogger.info('   - Email: manager@test.com');
    AppLogger.info('   - Password: password123');
    AppLogger.info('   - Click "Add user"');
    AppLogger.info('');

    AppLogger.info('   👷 WORKER ACCOUNT:');
    AppLogger.info('   - Email: worker@test.com');
    AppLogger.info('   - Password: password123');
    AppLogger.info('   - Click "Add user"');
    AppLogger.info('');

    AppLogger.info('5. Next, add user documents to Firestore:');
    AppLogger.info('   - Navigate to Firestore Database');
    AppLogger.info('   - Create collection "users"');
    AppLogger.info(
      '   - For each user, create a document with their UID as the document ID',
    );
    AppLogger.info('');

    AppLogger.info('   MANAGER DOCUMENT:');
    AppLogger.info('   {');
    AppLogger.info('     "uid": "[manager-uid-from-auth]",');
    AppLogger.info('     "name": "Demo Manager",');
    AppLogger.info('     "role": "manager",');
    AppLogger.info('     "email": "manager@test.com"');
    AppLogger.info('   }');
    AppLogger.info('');

    AppLogger.info('   WORKER DOCUMENT:');
    AppLogger.info('   {');
    AppLogger.info('     "uid": "[worker-uid-from-auth]",');
    AppLogger.info('     "name": "Demo Worker",');
    AppLogger.info('     "role": "worker",');
    AppLogger.info('     "email": "worker@test.com"');
    AppLogger.info('   }');
    AppLogger.info('');

    AppLogger.info('6. Test the accounts by logging into the app');
    AppLogger.info('');
    AppLogger.warning(
      'Make sure to use the exact UIDs from the Authentication tab',
    );
    AppLogger.warning('as the document IDs in Firestore!');
    AppLogger.info('');
    AppLogger.success('=== END SETUP INSTRUCTIONS ===\n');
  }

  /// Quick test credentials reminder
  static void printTestCredentials() {
    AppLogger.info('\n=== TEST ACCOUNT CREDENTIALS ===');
    AppLogger.info('Manager: manager@test.com / password123');
    AppLogger.info('Worker: worker@test.com / password123');
    AppLogger.info('================================\n');
  }
}
