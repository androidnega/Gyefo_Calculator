import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:gyefo_clocking_app/utils/logger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized || kIsWeb) {
      return; // Skip initialization on web or if already initialized
    }

    try {
      // Initialize timezone data
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      AppLogger.info('Notification service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize notification service: $e');
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('Notification tapped: ${response.payload}');
    // Handle notification tap - could navigate to specific screen
  }

  /// Request notification permissions (Android 13+)
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      AppLogger.info('Notification permission result: $result');
      return result ?? false;
    } catch (e) {
      AppLogger.error('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Schedule a daily reminder at specific time
  static Future<void> scheduleClockInReminder({
    required int hour,
    required int minute,
    String? customMessage,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'clocking_reminders',
        'Clocking Reminders',
        channelDescription: 'Daily reminders to clock in and out',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the scheduled time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }      await _flutterLocalNotificationsPlugin.zonedSchedule(
        1, // Clock-in reminder ID
        'Time to Clock In! ⏰',
        customMessage ?? 'Don\'t forget to start your workday by clocking in.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: 'clock_in_reminder',
      );

      AppLogger.info('Clock-in reminder scheduled for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      AppLogger.error('Error scheduling clock-in reminder: $e');
    }
  }

  /// Schedule a daily clock-out reminder
  static Future<void> scheduleClockOutReminder({
    required int hour,
    required int minute,
    String? customMessage,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'clocking_reminders',
        'Clocking Reminders',
        channelDescription: 'Daily reminders to clock in and out',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the scheduled time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }      await _flutterLocalNotificationsPlugin.zonedSchedule(
        2, // Clock-out reminder ID
        'Time to Clock Out! 🏠',
        customMessage ?? 'Remember to clock out before ending your workday.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: 'clock_out_reminder',
      );

      AppLogger.info('Clock-out reminder scheduled for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      AppLogger.error('Error scheduling clock-out reminder: $e');
    }
  }

  /// Cancel all reminders
  static Future<void> cancelAllReminders() async {
    if (kIsWeb || !_isInitialized) return;

    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      AppLogger.info('All reminders cancelled');
    } catch (e) {
      AppLogger.error('Error cancelling reminders: $e');
    }
  }

  /// Cancel specific reminder
  static Future<void> cancelReminder(int id) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      AppLogger.info('Reminder $id cancelled');
    } catch (e) {
      AppLogger.error('Error cancelling reminder $id: $e');
    }
  }

  /// Get list of pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (kIsWeb || !_isInitialized) return [];

    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      AppLogger.error('Error getting pending notifications: $e');
      return [];
    }
  }

  /// Show immediate notification (for testing or instant alerts)
  static Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'instant_notifications',
        'Instant Notifications',
        channelDescription: 'Immediate notifications for important events',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        0, // Instant notification ID
        title,
        body,
        details,
        payload: payload,
      );

      AppLogger.info('Instant notification shown: $title');
    } catch (e) {
      AppLogger.error('Error showing instant notification: $e');
    }
  }
}
