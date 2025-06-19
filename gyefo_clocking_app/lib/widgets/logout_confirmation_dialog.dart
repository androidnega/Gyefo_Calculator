import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/session_manager.dart';
import '../services/auth_service.dart';

class LogoutConfirmationDialog extends StatelessWidget {
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isAutoLogout;
  final String? reason;

  const LogoutConfirmationDialog({
    super.key,
    this.onConfirm,
    this.onCancel,
    this.isAutoLogout = false,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color:
                    isAutoLogout
                        ? Colors.orange.withValues(alpha: 0.1)
                        : AppTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAutoLogout ? Icons.timer_off : Icons.logout,
                size: 32,
                color: isAutoLogout ? Colors.orange : AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              isAutoLogout ? 'Session Expired' : 'Confirm Logout',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              _getMessage(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            if (!isAutoLogout) ...[
              const SizedBox(height: 16),

              // Session info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your session will be saved and you can continue where you left off when you log back in.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                if (!isAutoLogout) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onCancel?.call();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _performLogout(context);
                      onConfirm?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isAutoLogout ? Colors.orange : AppTheme.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(isAutoLogout ? 'Continue' : 'Logout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMessage() {
    if (isAutoLogout) {
      return reason ??
          'Your session has expired due to inactivity. Please log in again to continue using the app.';
    } else {
      return 'Are you sure you want to log out? You will need to enter your credentials again to access the app.';
    }
  }

  Future<void> _performLogout(BuildContext context) async {
    try {
      // End the session
      await SessionManager().endSession();

      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Perform Firebase logout
      await AuthService().signOut();

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show logout confirmation dialog
  static Future<bool?> show(
    BuildContext context, {
    bool isAutoLogout = false,
    String? reason,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !isAutoLogout,
      builder:
          (context) => LogoutConfirmationDialog(
            isAutoLogout: isAutoLogout,
            reason: reason,
            onConfirm:
                () => Navigator.of(context, rootNavigator: true).pop(true),
            onCancel:
                () => Navigator.of(context, rootNavigator: true).pop(false),
          ),
    );
  }
}
