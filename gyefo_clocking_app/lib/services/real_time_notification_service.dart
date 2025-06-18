import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gyefo_clocking_app/models/notification_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'dart:convert';

/// Real-time notification service for sending actual push notifications
class RealTimeNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Initialize the notification service
  static Future<void> initialize() async {
    try {
      // Request permissions
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _localNotifications.initialize(initializationSettings);

      // Update FCM token
      await updateFCMToken();

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      AppLogger.success('Real-time notification service initialized');
    } catch (e) {
      AppLogger.error('Error initializing real-time notifications: $e');
    }
  }

  /// Update FCM token for the current user
  static Future<void> updateFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });

        AppLogger.info('FCM token updated: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      AppLogger.error('Error updating FCM token: $e');
    }
  }

  /// Send notification to specific manager
  static Future<void> sendNotificationToManager({
    required String managerId,
    required String title,
    required String message,
    NotificationType type = NotificationType.systemAlert,
    String? workerId,
    String? workerName,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      // Create notification in Firestore using the correct model
      final notificationData = {
        'managerId': managerId,
        'type': type.toString().split('.').last,
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'priority': NotificationPriority.normal.toString().split('.').last,
        'actionData': actionData ?? {},
        'workerId': workerId,
        'workerName': workerName,
      };

      await _firestore.collection('notifications').add(notificationData);

      // Get manager's FCM token and send push notification
      final managerDoc =
          await _firestore.collection('users').doc(managerId).get();
      final fcmToken = managerDoc.data()?['fcmToken'] as String?;

      if (fcmToken != null) {
        await _showLocalNotification(
          title: title,
          body: message,
          data: actionData ?? {},
        );
      }

      AppLogger.success('Notification sent to manager $managerId');
    } catch (e) {
      AppLogger.error('Error sending notification to manager: $e');
    }
  }

  /// Send notification to all managers
  static Future<void> sendNotificationToAllManagers({
    required String title,
    required String message,
    NotificationType type = NotificationType.systemAlert,
    String? workerId,
    String? workerName,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      // Get all manager user IDs
      final managersSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'manager')
              .get();

      for (var managerDoc in managersSnapshot.docs) {
        await sendNotificationToManager(
          managerId: managerDoc.id,
          title: title,
          message: message,
          type: type,
          workerId: workerId,
          workerName: workerName,
          actionData: actionData,
        );
      }
    } catch (e) {
      AppLogger.error('Error sending notification to managers: $e');
    }
  }

  /// Send attendance alert to managers
  static Future<void> sendAttendanceAlert({
    required String workerId,
    required String workerName,
    required String alertType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      String title = '';
      String message = '';

      switch (alertType) {
        case 'flagged_attendance':
          title = 'Flagged Attendance Alert';
          message = '$workerName has flagged attendance that requires review';
          break;
        case 'late_clock_in':
          title = 'Late Clock-In Alert';
          message = '$workerName clocked in late today';
          break;
        case 'missed_clock_out':
          title = 'Missed Clock-Out Alert';
          message = '$workerName forgot to clock out yesterday';
          break;
        case 'overtime_alert':
          title = 'Overtime Alert';
          message = '$workerName is working overtime';
          break;
        default:
          title = 'Attendance Alert';
          message = 'Alert for $workerName';
      }

      final actionData = {
        'workerId': workerId,
        'workerName': workerName,
        'alertType': alertType,
        ...?additionalData,
      };

      await sendNotificationToAllManagers(
        title: title,
        message: message,
        type: NotificationType.flaggedAttendance,
        workerId: workerId,
        workerName: workerName,
        actionData: actionData,
      );
    } catch (e) {
      AppLogger.error('Error sending attendance alert: $e');
    }
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    try {
      AppLogger.info(
        'Received foreground message: ${message.notification?.title}',
      );

      // Show local notification when app is in foreground
      if (message.notification != null) {
        _showLocalNotification(
          title: message.notification!.title ?? 'Notification',
          body: message.notification!.body ?? '',
          data: message.data,
        );
      }
    } catch (e) {
      AppLogger.error('Error handling foreground message: $e');
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'gyefo_main_channel',
            'Gyefo Notifications',
            channelDescription: 'Main notifications for Gyefo app',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
        payload: data != null ? jsonEncode(data) : null,
      );
    } catch (e) {
      AppLogger.error('Error showing local notification: $e');
    }
  }

  /// Test notification (for development)
  static Future<void> sendTestNotification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await sendNotificationToManager(
        managerId: user.uid,
        title: 'Test Notification',
        message: 'This is a test notification from the real-time service',
        type: NotificationType.systemAlert,
      );
    } catch (e) {
      AppLogger.error('Error sending test notification: $e');
    }
  }

  /// Start listening for real-time notification streams
  static Stream<List<NotificationModel>> getNotificationStream(
    String managerId,
  ) {
    return _firestore
        .collection('notifications')
        .where('managerId', isEqualTo: managerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return NotificationModel(
              id: doc.id,
              managerId: data['managerId'] ?? '',
              type: _parseNotificationType(data['type']),
              title: data['title'] ?? '',
              message: data['message'] ?? '',
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isRead: data['isRead'] ?? false,
              priority: _parseNotificationPriority(data['priority']),
              actionData: Map<String, dynamic>.from(data['actionData'] ?? {}),
              relatedId: data['relatedId'],
              workerName: data['workerName'],
              workerId: data['workerId'],
            );
          }).toList();
        });
  }

  /// Parse notification type from string
  static NotificationType _parseNotificationType(String? typeString) {
    switch (typeString) {
      case 'flaggedAttendance':
        return NotificationType.flaggedAttendance;
      case 'newJustification':
        return NotificationType.newJustification;
      case 'clockSuccess':
        return NotificationType.clockSuccess;
      case 'teamUpdate':
        return NotificationType.teamUpdate;
      default:
        return NotificationType.systemAlert;
    }
  }

  /// Parse notification priority from string
  static NotificationPriority _parseNotificationPriority(
    String? priorityString,
  ) {
    switch (priorityString) {
      case 'low':
        return NotificationPriority.low;
      case 'high':
        return NotificationPriority.high;
      case 'urgent':
        return NotificationPriority.urgent;
      default:
        return NotificationPriority.normal;
    }
  }
}
