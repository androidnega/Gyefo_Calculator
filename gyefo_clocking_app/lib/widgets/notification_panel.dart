import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/notification_model.dart';
import 'package:gyefo_clocking_app/services/manager_notification_service.dart';
import 'package:gyefo_clocking_app/screens/flagged_attendance_screen.dart';
import 'package:gyefo_clocking_app/screens/manager_attendance_screen.dart';
import 'package:gyefo_clocking_app/screens/team_management_screen.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:intl/intl.dart';

enum NotificationFilter { all, unread, flagged, justifications, clockEvents }

class NotificationPanel extends StatefulWidget {
  final String managerId;

  const NotificationPanel({super.key, required this.managerId});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  NotificationFilter _currentFilter = NotificationFilter.all;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'mark_all_read',
                      child: Row(
                        children: [
                          Icon(Icons.done_all, size: 20),
                          SizedBox(width: 8),
                          Text('Mark All Read'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'create_mock',
                      child: Row(
                        children: [
                          Icon(Icons.science, size: 20),
                          SizedBox(width: 8),
                          Text('Create Test Data'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cleanup',
                      child: Row(
                        children: [
                          Icon(Icons.cleaning_services, size: 20),
                          SizedBox(width: 8),
                          Text('Cleanup Old'),
                        ],
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<List<NotificationModel>>(
              stream: NotificationService.getManagerNotifications(
                widget.managerId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text('Error loading notifications: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final allNotifications = snapshot.data ?? [];
                final filteredNotifications = _filterNotifications(
                  allNotifications,
                );

                if (filteredNotifications.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    itemCount: filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = filteredNotifications[index];
                      return _buildNotificationItem(notification);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              NotificationFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_getFilterLabel(filter)),
                    selected: _currentFilter == filter,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _currentFilter = filter;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  String _getFilterLabel(NotificationFilter filter) {
    switch (filter) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.unread:
        return 'Unread';
      case NotificationFilter.flagged:
        return 'Flagged';
      case NotificationFilter.justifications:
        return 'Justifications';
      case NotificationFilter.clockEvents:
        return 'Clock Events';
    }
  }

  List<NotificationModel> _filterNotifications(
    List<NotificationModel> notifications,
  ) {
    switch (_currentFilter) {
      case NotificationFilter.all:
        return notifications;
      case NotificationFilter.unread:
        return notifications.where((n) => !n.isRead).toList();
      case NotificationFilter.flagged:
        return notifications
            .where((n) => n.type == NotificationType.flaggedAttendance)
            .toList();
      case NotificationFilter.justifications:
        return notifications
            .where((n) => n.type == NotificationType.newJustification)
            .toList();
      case NotificationFilter.clockEvents:
        return notifications
            .where((n) => n.type == NotificationType.clockSuccess)
            .toList();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No ${_getFilterLabel(_currentFilter).toLowerCase()} notifications',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'When events occur, notifications will appear here',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: notification.isRead ? 1 : 3,
        color: notification.isRead ? null : Colors.blue[50],
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getNotificationIcon(notification.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    fontWeight:
                                        notification.isRead
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    _getPriorityIndicator(notification.priority),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (notification.workerName != null) ...[
                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            notification.workerName!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(notification.createdAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (!notification.isRead)
                          IconButton(
                            icon: const Icon(Icons.mark_email_read, size: 20),
                            onPressed: () => _markAsRead(notification),
                            tooltip: 'Mark as read',
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteNotification(notification),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.flaggedAttendance:
        iconData = Icons.flag;
        color = Colors.red;
        break;
      case NotificationType.newJustification:
        iconData = Icons.assignment;
        color = Colors.orange;
        break;
      case NotificationType.clockSuccess:
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.teamUpdate:
        iconData = Icons.groups;
        color = Colors.blue;
        break;
      case NotificationType.systemAlert:
        iconData = Icons.warning;
        color = Colors.amber;
        break;
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(iconData, color: color, size: 20),
    );
  }

  Widget _getPriorityIndicator(NotificationPriority priority) {
    Color color;
    switch (priority) {
      case NotificationPriority.low:
        color = Colors.grey;
        break;
      case NotificationPriority.normal:
        color = Colors.blue;
        break;
      case NotificationPriority.high:
        color = Colors.orange;
        break;
      case NotificationPriority.urgent:
        color = Colors.red;
        break;
    }

    return Container(
      width: 4,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read when tapped
    if (!notification.isRead) {
      _markAsRead(notification);
    }

    // Navigate to relevant screen based on notification type
    _navigateToRelevantScreen(notification);
  }

  void _navigateToRelevantScreen(NotificationModel notification) {
    // This will integrate with the existing navigation service
    AppLogger.info('Navigate to screen for notification: ${notification.type}');

    // Navigate to the relevant screen without closing the notification panel
    // This maintains the navigation stack so back button returns to notifications
    switch (notification.type) {
      case NotificationType.flaggedAttendance:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FlaggedAttendanceScreen(),
          ),
        );
        break;
      case NotificationType.newJustification:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FlaggedAttendanceScreen(),
          ),
        );
        break;
      case NotificationType.clockSuccess:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ManagerAttendanceScreen(),
          ),
        );
        break;
      case NotificationType.teamUpdate:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TeamManagementScreen()),
        );
        break;
      case NotificationType.systemAlert:
        // Show alert dialog for system alerts
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(notification.title),
                content: Text(notification.message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
        break;
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    try {
      await NotificationService.markAsRead(notification.id);
      AppLogger.info('Notification marked as read: ${notification.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking notification as read: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text(
              'Are you sure you want to delete this notification?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await NotificationService.deleteNotification(notification.id);
        AppLogger.info('Notification deleted: ${notification.id}');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting notification: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleMenuAction(String action) async {
    setState(() {
      _isLoading = true;
    });

    try {
      switch (action) {
        case 'mark_all_read':
          await NotificationService.markAllAsRead(widget.managerId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All notifications marked as read'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;
        case 'create_mock':
          await NotificationService.createMockNotifications(widget.managerId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mock notifications created'),
                backgroundColor: Colors.blue,
              ),
            );
          }
          break;
        case 'cleanup':
          await NotificationService.cleanupOldNotifications(widget.managerId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Old notifications cleaned up'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
