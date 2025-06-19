import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionManager with WidgetsBindingObserver {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  static const String _lastPausedTimeKey = 'last_paused_time';
  static const String _sessionActiveKey = 'session_active';
  static const String _lastBootTimeKey = 'last_boot_time';

  // Session timeout in minutes (configurable)
  static const int sessionTimeoutMinutes = 10;

  Timer? _sessionTimer;
  DateTime? _lastPausedTime;
  bool _isSessionActive = true;
  bool _isInitialized = false;

  // Callback for when session expires
  VoidCallback? onSessionExpired;

  /// Initialize session manager
  Future<void> initialize({VoidCallback? onExpired}) async {
    if (_isInitialized) return;

    onSessionExpired = onExpired;
    WidgetsBinding.instance.addObserver(this);

    await _checkBootTime();
    await _restoreSessionState();
    _startSessionTimer();

    _isInitialized = true;
    debugPrint('SessionManager initialized');
  }

  /// Dispose session manager
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _isInitialized = false;
    debugPrint('SessionManager disposed');
  }

  /// Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.inactive:
        // App is transitioning, do nothing
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running
        break;
    }
  }

  /// Handle when app is paused or sent to background
  Future<void> _handleAppPaused() async {
    _lastPausedTime = DateTime.now();
    _sessionTimer?.cancel();

    // Save pause time to persistent storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastPausedTimeKey,
      _lastPausedTime!.toIso8601String(),
    );
    await prefs.setBool(_sessionActiveKey, true);

    debugPrint('App paused at: $_lastPausedTime');
  }

  /// Handle when app is resumed from background
  Future<void> _handleAppResumed() async {
    final prefs = await SharedPreferences.getInstance();
    final pausedTimeString = prefs.getString(_lastPausedTimeKey);

    if (pausedTimeString != null) {
      final pausedTime = DateTime.parse(pausedTimeString);
      final resumeTime = DateTime.now();
      final timeDifference = resumeTime.difference(pausedTime);

      debugPrint('App resumed after: ${timeDifference.inMinutes} minutes');

      // Check if session has expired
      if (timeDifference.inMinutes >= sessionTimeoutMinutes) {
        debugPrint('Session expired due to inactivity');
        await _handleSessionExpired();
        return;
      }
    }

    // Session is still valid, restart timer
    _startSessionTimer();
    debugPrint('Session resumed successfully');
  }

  /// Check if app was restarted due to system reboot
  Future<void> _checkBootTime() async {
    final prefs = await SharedPreferences.getInstance();
    final currentBootTime = await _getSystemBootTime();
    final lastBootTime = prefs.getInt(_lastBootTimeKey) ?? 0;

    if (currentBootTime > lastBootTime) {
      // System was rebooted, clear session
      debugPrint('System reboot detected, clearing session');
      await _clearSession();
      await prefs.setInt(_lastBootTimeKey, currentBootTime);
    }
  }

  /// Get approximate system boot time (in milliseconds since epoch)
  Future<int> _getSystemBootTime() async {
    // This is an approximation - in a real app you might use platform channels
    // to get actual boot time from the system
    return DateTime.now().millisecondsSinceEpoch -
        (DateTime.now().millisecondsSinceEpoch % (24 * 60 * 60 * 1000));
  }

  /// Restore session state from storage
  Future<void> _restoreSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    final isSessionActive = prefs.getBool(_sessionActiveKey) ?? false;
    final pausedTimeString = prefs.getString(_lastPausedTimeKey);

    if (!isSessionActive || pausedTimeString == null) {
      // No previous session or session was already cleared
      return;
    }

    final pausedTime = DateTime.parse(pausedTimeString);
    final currentTime = DateTime.now();
    final timeDifference = currentTime.difference(pausedTime);

    if (timeDifference.inMinutes >= sessionTimeoutMinutes) {
      debugPrint('Previous session expired during app closure');
      await _handleSessionExpired();
    }
  }

  /// Start session timeout timer
  void _startSessionTimer() {
    _sessionTimer?.cancel();

    _sessionTimer = Timer(Duration(minutes: sessionTimeoutMinutes), () async {
      debugPrint('Session timeout reached');
      await _handleSessionExpired();
    });
  }

  /// Handle session expiration
  Future<void> _handleSessionExpired() async {
    _isSessionActive = false;
    await _clearSession();

    // Trigger logout callback
    if (onSessionExpired != null) {
      onSessionExpired!();
    } else {
      // Fallback logout
      await _performLogout();
    }
  }

  /// Clear session data
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPausedTimeKey);
    await prefs.setBool(_sessionActiveKey, false);
    _sessionTimer?.cancel();
  }

  /// Perform logout operation
  Future<void> _performLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('User logged out due to session expiry');
    } catch (e) {
      debugPrint('Error during auto logout: $e');
    }
  }

  /// Manually extend session (call this on user activity)
  void extendSession() {
    if (_isSessionActive) {
      _startSessionTimer();
      debugPrint('Session extended');
    }
  }

  /// Check if session is currently active
  bool get isSessionActive => _isSessionActive;

  /// Get remaining session time in minutes
  int get remainingSessionMinutes {
    if (_lastPausedTime != null) {
      final elapsed = DateTime.now().difference(_lastPausedTime!).inMinutes;
      return (sessionTimeoutMinutes - elapsed).clamp(0, sessionTimeoutMinutes);
    }
    return sessionTimeoutMinutes;
  }

  /// Manually end session (for logout)
  Future<void> endSession() async {
    _isSessionActive = false;
    await _clearSession();
    debugPrint('Session ended manually');
  }
}
