import 'dart:io';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:gyefo_clocking_app/utils/demo_setup_new.dart';

void main() async {
  AppLogger.info('\n=== Gyefo Clocking App Demo Account Setup ===\n');

  AppLogger.info('This script helps you set up demo accounts for testing.');
  AppLogger.info('Choose an option:\n');

  AppLogger.info('1. Automatic Setup (requires Firebase connection)');
  AppLogger.info('2. Manual Setup Instructions');
  AppLogger.info('3. Test Credentials Only');
  AppLogger.info('\nEnter your choice (1, 2, or 3): ');

  String? input = stdin.readLineSync();

  switch (input) {
    case '1':
      AppLogger.info('\nStarting automatic setup...');
      await DemoSetup.createDemoAccounts();
      break;

    case '2':
      _printManualInstructions();
      break;

    case '3':
      _printTestCredentials();
      break;

    default:
      AppLogger.error(
        'Invalid choice. Please run again and select 1, 2, or 3.',
      );
  }
}

void _printManualInstructions() {
  AppLogger.info('\n=== MANUAL DEMO ACCOUNT SETUP INSTRUCTIONS ===\n');

  AppLogger.info('Follow these steps to create demo accounts manually:');
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
    'IMPORTANT: Use the exact UIDs from the Authentication tab',
  );
  AppLogger.warning('as the document IDs in Firestore!');
  AppLogger.info('');
  AppLogger.success('=== END SETUP INSTRUCTIONS ===\n');
}

void _printTestCredentials() {
  AppLogger.info('\n=== TEST ACCOUNT CREDENTIALS ===');
  AppLogger.info('');
  AppLogger.info('Manager Account:');
  AppLogger.info('  Email: manager@test.com');
  AppLogger.info('  Password: password123');
  AppLogger.info('  Access: Create workers, view all attendance');
  AppLogger.info('');
  AppLogger.info('Worker Account:');
  AppLogger.info('  Email: worker@test.com');
  AppLogger.info('  Password: password123');
  AppLogger.info('  Access: Clock in/out, view personal attendance');
  AppLogger.info('');
  AppLogger.info('Use these credentials to test the app functionality.');
  AppLogger.success('================================\n');
}
