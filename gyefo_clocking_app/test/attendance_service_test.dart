import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gyefo_clocking_app/services/attendance_service.dart';
import 'package:gyefo_clocking_app/firebase_options.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

void main() {
  group('Attendance Service Tests', () {
    setUpAll(() async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    });

    test('Clock-in functionality test', () async {
      final attendanceService = AttendanceService();
      const testWorkerId = 'test_worker_id';

      try {
        // Test hasClockedInToday
        final hasClocked = await attendanceService.hasClockedInToday(
          testWorkerId,
        );
        AppLogger.info('Has clocked in today: $hasClocked');

        // If not clocked in, try to clock in
        if (!hasClocked) {
          await attendanceService.clockIn(testWorkerId);
          AppLogger.success('Clock-in successful');
        } else {
          AppLogger.info('Already clocked in today');
        }

        expect(true, true); // Test passes if no exceptions thrown
      } catch (e) {
        AppLogger.error('Test failed with error: $e');
        expect(false, true, reason: 'Clock-in test failed: $e');
      }
    });
  });
}
