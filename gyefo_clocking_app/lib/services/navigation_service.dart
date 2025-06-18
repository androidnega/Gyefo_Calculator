import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyefo_clocking_app/screens/flagged_attendance_screen.dart';
import 'package:gyefo_clocking_app/screens/worker_attendance_detail_screen.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Navigate to appropriate screen based on notification data
  static Future<void> navigateFromNotification(
    Map<String, dynamic> data,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      AppLogger.warning(
        'NavigationService: No context available for navigation',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppLogger.warning('NavigationService: No authenticated user');
      return;
    }

    final type = data['type'];

    try {
      switch (type) {
        case 'clock_success':
          await _navigateToAttendanceHistory(context, user.uid);
          break;
        case 'justification_status':
          final justificationId = data['justificationId'];
          await _navigateToJustificationDetails(
            context,
            user.uid,
            justificationId,
          );
          break;
        case 'flagged_attendance':
          await _navigateToFlaggedAttendance(context);
          break;
        case 'new_justification':
          await _navigateToJustificationReview(context);
          break;
        default:
          AppLogger.warning(
            'NavigationService: Unknown notification type: $type',
          );
      }
    } catch (e) {
      AppLogger.error(
        'NavigationService: Error navigating from notification: $e',
      );
    }
  }

  /// Navigate to worker's attendance history
  static Future<void> _navigateToAttendanceHistory(
    BuildContext context,
    String workerId,
  ) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkerAttendanceDetailScreen(workerId: workerId),
      ),
    );
    AppLogger.info(
      'NavigationService: Navigated to attendance history for worker: $workerId',
    );
  }

  /// Navigate to justification details (workers can view their justification status)
  static Future<void> _navigateToJustificationDetails(
    BuildContext context,
    String workerId,
    String? justificationId,
  ) async {
    if (justificationId == null) {
      AppLogger.warning('NavigationService: No justification ID provided');
      return;
    }

    // Navigate to worker's attendance history where they can see justification status
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkerAttendanceDetailScreen(workerId: workerId),
      ),
    );
    AppLogger.info(
      'NavigationService: Navigated to attendance history for justification: $justificationId',
    );
  }

  /// Navigate to flagged attendance screen (managers only)
  static Future<void> _navigateToFlaggedAttendance(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user is a manager
    final userRole = await FirestoreService.getUserRole(user.uid);
    if (userRole != 'manager') {
      AppLogger.warning(
        'NavigationService: Non-manager tried to access flagged attendance',
      );
      return;
    }

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const FlaggedAttendanceScreen(),
        ),
      );
      AppLogger.info(
        'NavigationService: Navigated to flagged attendance screen',
      );
    }
  }

  /// Navigate to justification review screen (managers only)
  static Future<void> _navigateToJustificationReview(
    BuildContext context,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user is a manager
    final userRole = await FirestoreService.getUserRole(user.uid);
    if (userRole != 'manager') {
      AppLogger.warning(
        'NavigationService: Non-manager tried to access justification review',
      );
      return;
    }

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const FlaggedAttendanceScreen(),
        ),
      );
      AppLogger.info(
        'NavigationService: Navigated to justification review screen',
      );
    }
  }
}
