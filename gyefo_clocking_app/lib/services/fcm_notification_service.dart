import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class FCMNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Notification types
  static const String TYPE_CLOCK_SUCCESS = 'clock_success';
  static const String TYPE_JUSTIFICATION_STATUS = 'justification_status';
  static const String TYPE_FLAGGED_ATTENDANCE = 'flagged_attendance';
  static const String TYPE_NEW_JUSTIFICATION = 'new_justification';

  static Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
    } else {
      print('User declined or has not accepted permission for notifications');
      return;
    }

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

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    ); // Handle notification when app is terminated
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });

    // Get and save FCM token
    await _updateFCMToken();
  }

  /// Update FCM token for the current user
  static Future<void> _updateFCMToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token updated: $token');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM token refreshed: $newToken');
      } catch (e) {
        print('Error updating refreshed FCM token: $e');
      }
    });
  }

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');

    // Show local notification when app is in foreground
    await _showLocalNotification(message);
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'gyefo_attendance_channel',
          'Attendance Notifications',
          channelDescription: 'Notifications for attendance events',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Gyefo Attendance',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    // TODO: Navigate to appropriate screen based on notification type
    _processNotificationAction(message.data);
  }

  /// Handle notification response from local notifications
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _processNotificationAction(data);
      } catch (e) {
        print('Error processing notification payload: $e');
      }
    }
  }

  /// Process notification action based on type
  static void _processNotificationAction(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case TYPE_CLOCK_SUCCESS:
        // Navigate to attendance history or dashboard
        print('Processing clock success notification');
        break;
      case TYPE_JUSTIFICATION_STATUS:
        // Navigate to justification details
        final justificationId = data['justificationId'];
        print('Processing justification status notification: $justificationId');
        break;
      case TYPE_FLAGGED_ATTENDANCE:
        // Navigate to flagged attendance screen (managers only)
        final attendanceId = data['attendanceId'];
        print('Processing flagged attendance notification: $attendanceId');
        break;
      case TYPE_NEW_JUSTIFICATION:
        // Navigate to justification review (managers only)
        final justificationId = data['justificationId'];
        print('Processing new justification notification: $justificationId');
        break;
      default:
        print('Unknown notification type: $type');
    }
  }

  /// Send clock success notification to worker
  static Future<void> sendClockSuccessNotification({
    required String userId,
    required String action, // 'clock_in' or 'clock_out'
    required DateTime timestamp,
  }) async {
    try {
      final userData = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userData.data()?['fcmToken'];

      if (fcmToken == null) {
        print('No FCM token found for user: $userId');
        return;
      }

      final actionText = action == 'clock_in' ? 'Clock In' : 'Clock Out';
      final timeText = _formatTime(timestamp);

      // Create notification document for Firebase Functions to process
      await _firestore.collection('notifications').add({
        'type': TYPE_CLOCK_SUCCESS,
        'userId': userId,
        'fcmToken': fcmToken,
        'title': '$actionText Successful',
        'body':
            'Successfully clocked ${action == 'clock_in' ? 'in' : 'out'} at $timeText',
        'data': {
          'type': TYPE_CLOCK_SUCCESS,
          'action': action,
          'timestamp': timestamp.toIso8601String(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      print('Clock success notification queued for user: $userId');
    } catch (e) {
      print('Error sending clock success notification: $e');
    }
  }

  /// Send justification status notification to worker
  static Future<void> sendJustificationStatusNotification({
    required String userId,
    required String justificationId,
    required String status, // 'approved' or 'rejected'
    String? managerNote,
  }) async {
    try {
      final userData = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userData.data()?['fcmToken'];

      if (fcmToken == null) {
        print('No FCM token found for user: $userId');
        return;
      }

      final statusText = status == 'approved' ? 'Approved' : 'Rejected';
      final bodyText =
          managerNote != null
              ? 'Your justification has been $statusText. Note: $managerNote'
              : 'Your justification has been $statusText.';

      await _firestore.collection('notifications').add({
        'type': TYPE_JUSTIFICATION_STATUS,
        'userId': userId,
        'fcmToken': fcmToken,
        'title': 'Justification $statusText',
        'body': bodyText,
        'data': {
          'type': TYPE_JUSTIFICATION_STATUS,
          'justificationId': justificationId,
          'status': status,
          'managerNote': managerNote,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      print('Justification status notification queued for user: $userId');
    } catch (e) {
      print('Error sending justification status notification: $e');
    }
  }

  /// Send flagged attendance notification to managers
  static Future<void> sendFlaggedAttendanceNotification({
    required String attendanceId,
    required String workerName,
    required List<String> flags,
    required String companyId,
  }) async {
    try {
      // Get all managers in the company
      final managersQuery =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'manager')
              .where('companyId', isEqualTo: companyId)
              .get();

      final flagText = flags.join(', ');

      for (final managerDoc in managersQuery.docs) {
        final fcmToken = managerDoc.data()['fcmToken'];
        if (fcmToken == null) continue;

        await _firestore.collection('notifications').add({
          'type': TYPE_FLAGGED_ATTENDANCE,
          'userId': managerDoc.id,
          'fcmToken': fcmToken,
          'title': 'Flagged Attendance',
          'body': '$workerName has flagged attendance: $flagText',
          'data': {
            'type': TYPE_FLAGGED_ATTENDANCE,
            'attendanceId': attendanceId,
            'workerName': workerName,
            'flags': flags,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
      }

      print('Flagged attendance notifications queued for company: $companyId');
    } catch (e) {
      print('Error sending flagged attendance notifications: $e');
    }
  }

  /// Send new justification notification to managers
  static Future<void> sendNewJustificationNotification({
    required String justificationId,
    required String workerName,
    required String reason,
    required String companyId,
  }) async {
    try {
      // Get all managers in the company
      final managersQuery =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'manager')
              .where('companyId', isEqualTo: companyId)
              .get();

      for (final managerDoc in managersQuery.docs) {
        final fcmToken = managerDoc.data()['fcmToken'];
        if (fcmToken == null) continue;

        await _firestore.collection('notifications').add({
          'type': TYPE_NEW_JUSTIFICATION,
          'userId': managerDoc.id,
          'fcmToken': fcmToken,
          'title': 'New Justification',
          'body': '$workerName submitted a justification: $reason',
          'data': {
            'type': TYPE_NEW_JUSTIFICATION,
            'justificationId': justificationId,
            'workerName': workerName,
            'reason': reason,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
      }

      print('New justification notifications queued for company: $companyId');
    } catch (e) {
      print('Error sending new justification notifications: $e');
    }
  }

  /// Format time for display
  static String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Clean up old notification documents (call periodically)
  static Future<void> cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      final oldNotificationsQuery =
          await _firestore
              .collection('notifications')
              .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
              .get();

      final batch = _firestore.batch();
      for (final doc in oldNotificationsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print(
        'Cleaned up ${oldNotificationsQuery.docs.length} old notifications',
      );
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }

  /// Get notification permission status
  static Future<bool> hasNotificationPermission() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Request notification permission
  static Future<bool> requestNotificationPermission() async {
    final settings = await _firebaseMessaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
