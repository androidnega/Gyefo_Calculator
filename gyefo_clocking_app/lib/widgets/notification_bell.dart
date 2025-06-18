import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/services/manager_notification_service.dart';
import 'package:gyefo_clocking_app/widgets/notification_panel.dart';

class NotificationBell extends StatelessWidget {
  final String managerId;
  final Color? iconColor;
  final double iconSize;

  const NotificationBell({
    super.key,
    required this.managerId,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.getUnreadNotificationsCount(managerId),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications,
                color: iconColor ?? Theme.of(context).iconTheme.color,
                size: iconSize,
              ),
              onPressed: () => _openNotificationPanel(context),
              tooltip:
                  'Notifications${unreadCount > 0 ? ' ($unreadCount unread)' : ''}',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openNotificationPanel(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationPanel(managerId: managerId),
      ),
    );
  }
}
