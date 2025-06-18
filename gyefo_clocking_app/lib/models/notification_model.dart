import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  flaggedAttendance,
  newJustification,
  clockSuccess,
  systemAlert,
  teamUpdate,
}

enum NotificationPriority { low, normal, high, urgent }

class NotificationModel {
  final String id;
  final String managerId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final NotificationPriority priority;
  final Map<String, dynamic>? actionData;
  final String? relatedId; // attendance ID, justification ID, etc.
  final String? workerName;
  final String? workerId;

  NotificationModel({
    required this.id,
    required this.managerId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
    this.actionData,
    this.relatedId,
    this.workerName,
    this.workerId,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      managerId: data['managerId'] ?? '',
      type: NotificationType.values.firstWhere(
        (t) => t.toString() == data['type'],
        orElse: () => NotificationType.systemAlert,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      priority: NotificationPriority.values.firstWhere(
        (p) => p.toString() == data['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      actionData: data['actionData'] as Map<String, dynamic>?,
      relatedId: data['relatedId'],
      workerName: data['workerName'],
      workerId: data['workerId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'managerId': managerId,
      'type': type.toString(),
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'priority': priority.toString(),
      'actionData': actionData,
      'relatedId': relatedId,
      'workerName': workerName,
      'workerId': workerId,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? managerId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    NotificationPriority? priority,
    Map<String, dynamic>? actionData,
    String? relatedId,
    String? workerName,
    String? workerId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      managerId: managerId ?? this.managerId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      actionData: actionData ?? this.actionData,
      relatedId: relatedId ?? this.relatedId,
      workerName: workerName ?? this.workerName,
      workerId: workerId ?? this.workerId,
    );
  }
}
