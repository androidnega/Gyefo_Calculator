import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyefo_clocking_app/services/manager_notification_service.dart';
import 'package:gyefo_clocking_app/models/notification_model.dart';

class NotificationDemoScreen extends StatelessWidget {
  const NotificationDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final managerId = user?.uid ?? 'demo_manager';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Demo'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification System Demo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Test the notification system by creating different types of notifications. '
                      'Check the bell icon in the manager dashboard to see the notifications.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Create Test Notifications:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildNotificationButton(
              context,
              'Flagged Attendance',
              'Create a high-priority flagged attendance notification',
              Icons.flag,
              Colors.red,
              () => _createFlaggedNotification(managerId),
            ),
            const SizedBox(height: 12),
            _buildNotificationButton(
              context,
              'New Justification',
              'Create a justification submission notification',
              Icons.assignment,
              Colors.orange,
              () => _createJustificationNotification(managerId),
            ),
            const SizedBox(height: 12),
            _buildNotificationButton(
              context,
              'Clock-in Success',
              'Create a successful clock-in notification',
              Icons.check_circle,
              Colors.green,
              () => _createClockSuccessNotification(managerId),
            ),
            const SizedBox(height: 12),
            _buildNotificationButton(
              context,
              'System Alert',
              'Create a system alert notification',
              Icons.warning,
              Colors.amber,
              () => _createSystemNotification(managerId),
            ),
            const SizedBox(height: 12),
            _buildNotificationButton(
              context,
              'Team Update',
              'Create a team update notification',
              Icons.groups,
              Colors.blue,
              () => _createTeamNotification(managerId),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _createAllMockNotifications(context, managerId),
              icon: const Icon(Icons.science),
              label: const Text('Create All Mock Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationButton(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createFlaggedNotification(String managerId) async {
    await NotificationService.createNotification(
      managerId: managerId,
      type: NotificationType.flaggedAttendance,
      title: 'Flagged Attendance Alert',
      message: 'John Doe clocked in outside the allowed location',
      priority: NotificationPriority.high,
      workerName: 'John Doe',
      workerId: 'worker_123',
      relatedId: 'attendance_${DateTime.now().millisecondsSinceEpoch}',
      actionData: {
        'attendanceId': 'attendance_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'location_flag',
        'reason': 'Outside work zone',
      },
    );
  }

  Future<void> _createJustificationNotification(String managerId) async {
    await NotificationService.createNotification(
      managerId: managerId,
      type: NotificationType.newJustification,
      title: 'New Justification Submitted',
      message: 'Sarah Wilson submitted a justification for late clock-in',
      priority: NotificationPriority.normal,
      workerName: 'Sarah Wilson',
      workerId: 'worker_456',
      relatedId: 'justification_${DateTime.now().millisecondsSinceEpoch}',
      actionData: {
        'justificationId':
            'justification_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'late_arrival',
      },
    );
  }

  Future<void> _createClockSuccessNotification(String managerId) async {
    await NotificationService.createNotification(
      managerId: managerId,
      type: NotificationType.clockSuccess,
      title: 'Clock-in Successful',
      message: 'Mike Johnson clocked in successfully at ${_getCurrentTime()}',
      priority: NotificationPriority.low,
      workerName: 'Mike Johnson',
      workerId: 'worker_789',
      relatedId: 'attendance_${DateTime.now().millisecondsSinceEpoch}',
      actionData: {
        'attendanceId': 'attendance_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'clock_success',
        'action': 'clock_in',
      },
    );
  }

  Future<void> _createSystemNotification(String managerId) async {
    await NotificationService.createNotification(
      managerId: managerId,
      type: NotificationType.systemAlert,
      title: 'System Maintenance',
      message: 'Scheduled maintenance tonight from 11 PM to 1 AM',
      priority: NotificationPriority.urgent,
      actionData: {
        'type': 'maintenance',
        'startTime': '23:00',
        'endTime': '01:00',
      },
    );
  }

  Future<void> _createTeamNotification(String managerId) async {
    await NotificationService.createNotification(
      managerId: managerId,
      type: NotificationType.teamUpdate,
      title: 'Team Schedule Updated',
      message: 'Morning shift schedule has been updated for next week',
      priority: NotificationPriority.normal,
      actionData: {
        'shiftId': 'shift_morning',
        'type': 'schedule_update',
        'effectiveDate':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      },
    );
  }

  Future<void> _createAllMockNotifications(
    BuildContext context,
    String managerId,
  ) async {
    try {
      await NotificationService.createMockNotifications(managerId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All mock notifications created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating notifications: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour =
        now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
