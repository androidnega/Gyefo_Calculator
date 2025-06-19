import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../widgets/logout_confirmation_dialog.dart';

/// Mixin to add session management to stateful widgets
mixin SessionAwareMixin<T extends StatefulWidget> on State<T> {
  final SessionManager _sessionManager = SessionManager();
  bool _sessionInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSessionManagement();
  }

  @override
  void dispose() {
    if (_sessionInitialized) {
      _sessionManager.dispose();
    }
    super.dispose();
  }

  /// Initialize session management for this screen
  Future<void> _initializeSessionManagement() async {
    if (!_sessionInitialized) {
      await _sessionManager.initialize(onExpired: _handleSessionExpired);
      _sessionInitialized = true;
    }
  }

  /// Handle session expiration
  Future<void> _handleSessionExpired() async {
    if (mounted) {
      await LogoutConfirmationDialog.show(
        context,
        isAutoLogout: true,
        reason: 'Your session has expired due to inactivity.',
      );
    }
  }

  /// Extend the current session (call on user activity)
  void extendSession() {
    _sessionManager.extendSession();
  }

  /// Manually end session (for logout)
  Future<void> endSession() async {
    await _sessionManager.endSession();
  }

  /// Show logout confirmation dialog for manual logout
  Future<bool> showLogoutConfirmation() async {
    final result = await LogoutConfirmationDialog.show(
      context,
      isAutoLogout: false,
    );
    return result ?? false;
  }

  /// Check if session is active
  bool get isSessionActive => _sessionManager.isSessionActive;

  /// Get remaining session time in minutes
  int get remainingSessionMinutes => _sessionManager.remainingSessionMinutes;
}
