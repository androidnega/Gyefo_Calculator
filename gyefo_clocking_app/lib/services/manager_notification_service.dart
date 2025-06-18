import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/notification_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new notification for a manager
  static Future<void> createNotification({
    required String managerId,
    required NotificationType type,
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? actionData,
    String? relatedId,
    String? workerName,
    String? workerId,
  }) async {
    try {
      final notification = NotificationModel(
        id: '', // Will be set by Firestore
        managerId: managerId,
        type: type,
        title: title,
        message: message,
        createdAt: DateTime.now(),
        priority: priority,
        actionData: actionData,
        relatedId: relatedId,
        workerName: workerName,
        workerId: workerId,
      );

      await _firestore
          .collection('notifications')
          .add(notification.toFirestore());

      AppLogger.info('Notification created for manager: $managerId');
    } catch (e) {
      AppLogger.error('Error creating notification: $e');
      throw Exception('Failed to create notification: $e');
    }
  }

  /// Get notifications for a specific manager
  static Stream<List<NotificationModel>> getManagerNotifications(
    String managerId,
  ) {
    return _firestore
        .collection('notifications')
        .where('managerId', isEqualTo: managerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get unread notifications count for a manager
  static Stream<int> getUnreadNotificationsCount(String managerId) {
    return _firestore
        .collection('notifications')
        .where('managerId', isEqualTo: managerId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });

      AppLogger.info('Notification marked as read: $notificationId');
    } catch (e) {
      AppLogger.error('Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read for a manager
  static Future<void> markAllAsRead(String managerId) async {
    try {
      final unreadNotifications =
          await _firestore
              .collection('notifications')
              .where('managerId', isEqualTo: managerId)
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      AppLogger.info(
        'All notifications marked as read for manager: $managerId',
      );
    } catch (e) {
      AppLogger.error('Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      AppLogger.info('Notification deleted: $notificationId');
    } catch (e) {
      AppLogger.error('Error deleting notification: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }

  /// Delete old notifications (older than 30 days)
  static Future<void> cleanupOldNotifications(String managerId) async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final oldNotifications =
          await _firestore
              .collection('notifications')
              .where('managerId', isEqualTo: managerId)
              .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
              .get();

      final batch = _firestore.batch();
      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      AppLogger.info('Old notifications cleaned up for manager: $managerId');
    } catch (e) {
      AppLogger.error('Error cleaning up old notifications: $e');
    }
  }

  /// Create test/mock notifications for development
  static Future<void> createMockNotifications(String managerId) async {
    final mockNotifications = [
      {
        'type': NotificationType.flaggedAttendance,
        'title': 'Flagged Attendance Alert',
        'message': 'John Doe clocked in outside the allowed location',
        'priority': NotificationPriority.high,
        'workerName': 'John Doe',
        'workerId': 'worker_123',
        'relatedId': 'attendance_001',
        'actionData': {
          'attendanceId': 'attendance_001',
          'type': 'location_flag',
        },
      },
      {
        'type': NotificationType.newJustification,
        'title': 'New Justification Submitted',
        'message': 'Sarah Wilson submitted a justification for late clock-in',
        'priority': NotificationPriority.normal,
        'workerName': 'Sarah Wilson',
        'workerId': 'worker_456',
        'relatedId': 'justification_002',
        'actionData': {'justificationId': 'justification_002'},
      },
      {
        'type': NotificationType.clockSuccess,
        'title': 'Clock-in Successful',
        'message': 'Mike Johnson clocked in successfully at 8:30 AM',
        'priority': NotificationPriority.low,
        'workerName': 'Mike Johnson',
        'workerId': 'worker_789',
        'relatedId': 'attendance_003',
      },
      {
        'type': NotificationType.teamUpdate,
        'title': 'Team Schedule Updated',
        'message': 'Morning shift schedule has been updated for next week',
        'priority': NotificationPriority.normal,
        'actionData': {'shiftId': 'shift_morning', 'type': 'schedule_update'},
      },
      {
        'type': NotificationType.systemAlert,
        'title': 'System Maintenance',
        'message': 'Scheduled maintenance tonight from 11 PM to 1 AM',
        'priority': NotificationPriority.urgent,
      },
    ];

    for (final notification in mockNotifications) {
      await createNotification(
        managerId: managerId,
        type: notification['type'] as NotificationType,
        title: notification['title'] as String,
        message: notification['message'] as String,
        priority:
            notification['priority'] as NotificationPriority? ??
            NotificationPriority.normal,
        workerName: notification['workerName'] as String?,
        workerId: notification['workerId'] as String?,
        relatedId: notification['relatedId'] as String?,
        actionData: notification['actionData'] as Map<String, dynamic>?,
      );
    }

    AppLogger.info('Mock notifications created for manager: $managerId');
  }

  /// Helper method to create specific notification types
  static Future<void> createFlaggedAttendanceNotification({
    required String managerId,
    required String workerName,
    required String workerId,
    required String attendanceId,
    required String reason,
  }) async {
    await createNotification(
      managerId: managerId,
      type: NotificationType.flaggedAttendance,
      title: 'Flagged Attendance Alert',
      message: '$workerName has flagged attendance: $reason',
      priority: NotificationPriority.high,
      workerName: workerName,
      workerId: workerId,
      relatedId: attendanceId,
      actionData: {
        'attendanceId': attendanceId,
        'type': 'flagged_attendance',
        'reason': reason,
      },
    );
  }

  static Future<void> createJustificationNotification({
    required String managerId,
    required String workerName,
    required String workerId,
    required String justificationId,
  }) async {
    await createNotification(
      managerId: managerId,
      type: NotificationType.newJustification,
      title: 'New Justification Submitted',
      message: '$workerName submitted a justification for review',
      priority: NotificationPriority.normal,
      workerName: workerName,
      workerId: workerId,
      relatedId: justificationId,
      actionData: {
        'justificationId': justificationId,
        'type': 'new_justification',
      },
    );
  }

  static Future<void> createClockSuccessNotification({
    required String managerId,
    required String workerName,
    required String workerId,
    required String attendanceId,
    required String action, // 'clock_in' or 'clock_out'
  }) async {
    await createNotification(
      managerId: managerId,
      type: NotificationType.clockSuccess,
      title: 'Clock ${action == 'clock_in' ? 'In' : 'Out'} Successful',
      message:
          '$workerName clocked ${action == 'clock_in' ? 'in' : 'out'} successfully',
      priority: NotificationPriority.low,
      workerName: workerName,
      workerId: workerId,
      relatedId: attendanceId,
      actionData: {
        'attendanceId': attendanceId,
        'type': 'clock_success',
        'action': action,
      },
    );
  }
}
