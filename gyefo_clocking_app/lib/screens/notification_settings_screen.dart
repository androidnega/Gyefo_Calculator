import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/services/notification_service.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _clockInEnabled = false;
  bool _clockOutEnabled = false;
  TimeOfDay _clockInTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _clockOutTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load saved settings from SharedPreferences in a real app
    // For now, we'll use default values
    setState(() {
      _clockInEnabled = false;
      _clockOutEnabled = false;
    });
  }

  Future<void> _updateClockInReminder() async {
    if (_clockInEnabled) {
      await NotificationService.scheduleClockInReminder(
        hour: _clockInTime.hour,
        minute: _clockInTime.minute,
      );
      if (mounted) {
        AppLogger.info(
          'Clock-in reminder enabled for ${_clockInTime.format(context)}',
        );
      }
    } else {
      await NotificationService.cancelReminder(1); // Clock-in reminder ID
      AppLogger.info('Clock-in reminder disabled');
    }
  }

  Future<void> _updateClockOutReminder() async {
    if (_clockOutEnabled) {
      await NotificationService.scheduleClockOutReminder(
        hour: _clockOutTime.hour,
        minute: _clockOutTime.minute,
      );
      if (mounted) {
        AppLogger.info(
          'Clock-out reminder enabled for ${_clockOutTime.format(context)}',
        );
      }
    } else {
      await NotificationService.cancelReminder(2); // Clock-out reminder ID
      AppLogger.info('Clock-out reminder disabled');
    }
  }

  Future<void> _selectTime(bool isClockIn) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isClockIn ? _clockInTime : _clockOutTime,
    );

    if (picked != null) {
      setState(() {
        if (isClockIn) {
          _clockInTime = picked;
        } else {
          _clockOutTime = picked;
        }
      });

      // Update the reminder immediately if enabled
      if (isClockIn && _clockInEnabled) {
        await _updateClockInReminder();
      } else if (!isClockIn && _clockOutEnabled) {
        await _updateClockOutReminder();
      }
    }
  }

  Future<void> _testNotification() async {
    await NotificationService.showInstantNotification(
      title: 'Test Notification',
      body: 'Your notification system is working correctly! 🎉',
      payload: 'test',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Daily Reminders',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set up automatic reminders to help you remember to clock in and out.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Clock In Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.login, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Clock In Reminder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _clockInEnabled,
                          onChanged: (value) async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() {
                              _clockInEnabled = value;
                            });
                            await _updateClockInReminder();

                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? 'Clock-in reminder enabled'
                                      : 'Clock-in reminder disabled',
                                ),
                                backgroundColor:
                                    value ? Colors.green : Colors.orange,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (_clockInEnabled) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Reminder Time'),
                        subtitle: Text(_clockInTime.format(context)),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _selectTime(true),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Clock Out Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.logout, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text(
                          'Clock Out Reminder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _clockOutEnabled,
                          onChanged: (value) async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() {
                              _clockOutEnabled = value;
                            });
                            await _updateClockOutReminder();

                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? 'Clock-out reminder enabled'
                                        : 'Clock-out reminder disabled',
                                  ),
                                  backgroundColor:
                                      value ? Colors.green : Colors.orange,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    if (_clockOutEnabled) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Reminder Time'),
                        subtitle: Text(_clockOutTime.format(context)),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _selectTime(false),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Test Notification
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bug_report, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Test Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Test your notification system to make sure it\'s working properly.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _testNotification,
                        icon: const Icon(Icons.notifications),
                        label: const Text('Send Test Notification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Info Card
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Note',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reminders will repeat daily at the specified times. Make sure notifications are enabled in your device settings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
