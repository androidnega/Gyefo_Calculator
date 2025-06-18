import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'firebase_options.dart';

// Quick diagnostic tool to check teams in database
void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;

  AppLogger.info('🔍 Checking teams in database...\n');

  try {
    // Check if teams collection exists and has data
    final teamsSnapshot = await firestore.collection('teams').get();
    if (teamsSnapshot.docs.isEmpty) {
      AppLogger.warning('❌ No teams found in database');
      AppLogger.info(
        '📝 Would you like to create a sample team? (Run create_sample_team.dart)',
      );
    } else {
      AppLogger.info('✅ Found ${teamsSnapshot.docs.length} teams:');

      for (var doc in teamsSnapshot.docs) {
        final data = doc.data();
        AppLogger.info('  • ${data['name']} (ID: ${doc.id})');
        AppLogger.info('    - Manager: ${data['managerId']}');
        AppLogger.info('    - Members: ${data['memberIds']?.length ?? 0}');
        AppLogger.info('    - Active: ${data['isActive']}');
        AppLogger.info('    - Shift: ${data['shiftId'] ?? 'None'}\n');
      }
    }

    // Check users collection for managers
    final usersSnapshot =
        await firestore
            .collection('users')
            .where('role', isEqualTo: 'manager')
            .get();
    AppLogger.info(
      '👤 Found ${usersSnapshot.docs.length} managers in database',
    );

    if (usersSnapshot.docs.isNotEmpty) {
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        AppLogger.info(
          '  • ${data['name']} (${data['email']}) - ID: ${doc.id}',
        );
      }
    }
  } catch (e) {
    AppLogger.error('❌ Error checking database: $e');
  }

  AppLogger.info('\n🎯 If no teams found, create one in the app:');
  AppLogger.info('   Manager Dashboard → Team Management → + Create Team');
}
