import 'package:firebase_core/firebase_core.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'firebase_options.dart';
import 'lib/services/firebase_test.dart';

void main() async {
  AppLogger.info('\n=== Gyefo Clocking App - Firebase Test ===\n');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Run the test
    await testFirebaseAuth();
  } catch (e) {
    AppLogger.error('\nError initializing Firebase:');
    AppLogger.error(e.toString());
    AppLogger.error('\nPlease check your firebase_options.dart configuration.');
  }
}
