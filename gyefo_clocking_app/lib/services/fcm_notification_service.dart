import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:gyefo_clocking_app/services/navigation_service.dart';

class FCMNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  // Notification types
  static const String typeClockSuccess = 'clock_success';
  static const String typeJustificationStatus = 'justification_status';
  static const String typeFlaggedAttendance = 'flagged_attendance';
  static const String typeNewJustification = 'new_justification';

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
      AppLogger.info('User granted permission for notifications');
    } else {
      AppLogger.warning(
        'User declined or has not accepted permission for notifications',
      );
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
        AppLogger.info('FCM token updated: $token');
      }
    } catch (e) {
      AppLogger.error('Error updating FCM token: $e');
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        AppLogger.info('FCM token refreshed: $newToken');
      } catch (e) {
        AppLogger.error('Error updating refreshed FCM token: $e');
      }
    });
  }

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    AppLogger.info('Received foreground message: ${message.messageId}');

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
    AppLogger.info('Notification tapped: ${message.data}');
    _processNotificationAction(message.data);
    // Store navigation intent for the app to handle when it becomes active
    _storeNavigationIntent(message.data);
  }

  /// Handle notification response from local notifications
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _processNotificationAction(data);
      } catch (e) {
        AppLogger.error('Error processing notification payload: $e');
      }
    }
  }

  /// Process notification action based on type
  static void _processNotificationAction(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case typeClockSuccess:
        // Navigate to attendance history or dashboard
        AppLogger.info(
          'Processing clock success notification - should navigate to dashboard',
        );
        NavigationService.navigateFromNotification(data);
        break;
      case typeJustificationStatus:
        // Navigate to justification details
        final justificationId = data['justificationId'];
        AppLogger.info(
          'Processing justification status notification - should navigate to justification details: $justificationId',
        );
        NavigationService.navigateFromNotification(data);
        break;
      case typeFlaggedAttendance:
        // Navigate to flagged attendance screen (managers only)
        final attendanceId = data['attendanceId'];
        AppLogger.info(
          'Processing flagged attendance notification - should navigate to flagged attendance screen: $attendanceId',
        );
        NavigationService.navigateFromNotification(data);
        break;
      case typeNewJustification:
        // Navigate to justification review (managers only)
        final justificationId = data['justificationId'];
        AppLogger.info(
          'Processing new justification notification - should navigate to justification review: $justificationId',
        );
        NavigationService.navigateFromNotification(data);
        break;
      default:
        AppLogger.warning('Unknown notification type: $type');
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
        AppLogger.warning('No FCM token found for user: $userId');
        return;
      }

      final actionText = action == 'clock_in' ? 'Clock In' : 'Clock Out';
      final timeText = _formatTime(
        timestamp,
      ); // Create notification document for Firebase Functions to process
      await _firestore.collection('notifications').add({
        'type': typeClockSuccess,
        'userId': userId,
        'fcmToken': fcmToken,
        'title': '$actionText Successful',
        'body':
            'Successfully clocked ${action == 'clock_in' ? 'in' : 'out'} at $timeText',
        'data': {
          'type': typeClockSuccess,
          'action': action,
          'timestamp': timestamp.toIso8601String(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      AppLogger.info('Clock success notification queued for user: $userId');
    } catch (e) {
      AppLogger.error('Error sending clock success notification: $e');
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
        AppLogger.warning('No FCM token found for user: $userId');
        return;
      }

      final statusText = status == 'approved' ? 'Approved' : 'Rejected';
      final bodyText =
          managerNote != null
              ? 'Your justification has been $statusText. Note: $managerNote'
              : 'Your justification has been $statusText.';
      await _firestore.collection('notifications').add({
        'type': typeJustificationStatus,
        'userId': userId,
        'fcmToken': fcmToken,
        'title': 'Justification $statusText',
        'body': bodyText,
        'data': {
          'type': typeJustificationStatus,
          'justificationId': justificationId,
          'status': status,
          'managerNote': managerNote,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      AppLogger.info(
        'Justification status notification queued for user: $userId',
      );
    } catch (e) {
      AppLogger.error('Error sending justification status notification: $e');
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
          'type': typeFlaggedAttendance,
          'userId': managerDoc.id,
          'fcmToken': fcmToken,
          'title': 'Flagged Attendance',
          'body': '$workerName has flagged attendance: $flagText',
          'data': {
            'type': typeFlaggedAttendance,
            'attendanceId': attendanceId,
            'workerName': workerName,
            'flags': flags,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
      }
      AppLogger.info(
        'Flagged attendance notifications queued for company: $companyId',
      );
    } catch (e) {
      AppLogger.error('Error sending flagged attendance notifications: $e');
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
          'type': typeNewJustification,
          'userId': managerDoc.id,
          'fcmToken': fcmToken,
          'title': 'New Justification',
          'body': '$workerName submitted a justification: $reason',
          'data': {
            'type': typeNewJustification,
            'justificationId': justificationId,
            'workerName': workerName,
            'reason': reason,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'processed': false,
        });
      }
      AppLogger.info(
        'New justification notifications queued for company: $companyId',
      );
    } catch (e) {
      AppLogger.error('Error sending new justification notifications: $e');
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
      AppLogger.info(
        'Cleaned up ${oldNotificationsQuery.docs.length} old notifications',
      );
    } catch (e) {
      AppLogger.error('Error cleaning up old notifications: $e');
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

  /// Store navigation intent for app to handle when it becomes active
  static Future<void> _storeNavigationIntent(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_navigation', jsonEncode(data));
      AppLogger.info('Navigation intent stored: ${data['type']}');
    } catch (e) {
      AppLogger.error('Failed to store navigation intent: $e');
    }
  }

  /// Get and clear pending navigation intent
  static Future<Map<String, dynamic>?> getPendingNavigationIntent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final intentJson = prefs.getString('pending_navigation');
      if (intentJson != null) {
        await prefs.remove('pending_navigation');
        return jsonDecode(intentJson);
      }
    } catch (e) {
      AppLogger.error('Failed to get navigation intent: $e');
    }
    return null;
  }

  /// Check and handle pending navigation intent
  static Future<void> handlePendingNavigation() async {
    final intent = await getPendingNavigationIntent();
    if (intent != null) {
      AppLogger.info('Handling pending navigation: ${intent['type']}');
      _processNotificationAction(intent);
    }
  }
}
