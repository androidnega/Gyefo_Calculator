import 'package:intl/intl.dart';

class AttendanceLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isWithinWorkZone;
  final double? distanceFromWork;

  AttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.isWithinWorkZone,
    this.distanceFromWork,
  });

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
    'isWithinWorkZone': isWithinWorkZone,
    'distanceFromWork': distanceFromWork,
  };

  factory AttendanceLocation.fromMap(Map<String, dynamic> map) {
    return AttendanceLocation(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      accuracy: map['accuracy']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isWithinWorkZone: map['isWithinWorkZone'] ?? false,
      distanceFromWork: map['distanceFromWork']?.toDouble(),
    );
  }

  String get formattedDistance {
    if (distanceFromWork == null) return 'N/A';
    if (distanceFromWork! < 1000) {
      return '${distanceFromWork!.round()}m';
    } else {
      return '${(distanceFromWork! / 1000).toStringAsFixed(1)}km';
    }
  }
}

enum AttendanceFlag {
  late,
  overtime,
  outOfZone,
  longBreak,
  earlyClockOut,
  invalidDuration,
  suspicious,
  nonWorkingDay,
  unauthorizedOvertime,
}

enum JustificationStatus { pending, approved, rejected }

class AttendanceComment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorRole; // 'worker' or 'manager'
  final String comment;
  final DateTime timestamp;

  AttendanceComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'authorRole': authorRole,
    'comment': comment,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AttendanceComment.fromMap(Map<String, dynamic> map) {
    return AttendanceComment(
      id: map['id'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorRole: map['authorRole'] ?? 'worker',
      comment: map['comment'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class AttendanceJustification {
  final String reason;
  final JustificationStatus status;
  final DateTime submittedAt;
  final String? approvedByManagerId;
  final String? approvedByManagerName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final List<AttendanceComment> comments;

  AttendanceJustification({
    required this.reason,
    this.status = JustificationStatus.pending,
    required this.submittedAt,
    this.approvedByManagerId,
    this.approvedByManagerName,
    this.approvedAt,
    this.rejectionReason,
    this.comments = const [],
  });

  Map<String, dynamic> toMap() => {
    'reason': reason,
    'status': status.toString().split('.').last,
    'submittedAt': submittedAt.toIso8601String(),
    'approvedByManagerId': approvedByManagerId,
    'approvedByManagerName': approvedByManagerName,
    'approvedAt': approvedAt?.toIso8601String(),
    'rejectionReason': rejectionReason,
    'comments': comments.map((c) => c.toMap()).toList(),
  };

  factory AttendanceJustification.fromMap(Map<String, dynamic> map) {
    return AttendanceJustification(
      reason: map['reason'] ?? '',
      status: JustificationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => JustificationStatus.pending,
      ),
      submittedAt: DateTime.parse(map['submittedAt']),
      approvedByManagerId: map['approvedByManagerId'],
      approvedByManagerName: map['approvedByManagerName'],
      approvedAt:
          map['approvedAt'] != null ? DateTime.parse(map['approvedAt']) : null,
      rejectionReason: map['rejectionReason'],
      comments:
          (map['comments'] as List?)
              ?.map((c) => AttendanceComment.fromMap(c))
              .toList() ??
          [],
    );
  }
}

class AttendanceModel {
  final String workerId;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String date;
  final AttendanceLocation? clockInLocation;
  final AttendanceLocation? clockOutLocation;

  // Analytics and tracking fields
  final String? shiftId;
  final String? teamId;
  final Duration? scheduledDuration;
  final Duration? actualDuration;
  final Duration? latenessMinutes;
  final Duration? overtimeMinutes;
  final DateTime? expectedClockIn;
  final DateTime? expectedClockOut;

  // Flags and validation
  final List<AttendanceFlag> flags;
  final bool requiresJustification;
  final AttendanceJustification? justification;

  // Audit trail
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastModifiedBy;
  final List<String> auditLog;

  AttendanceModel({
    required this.workerId,
    required this.clockIn,
    this.clockOut,
    this.clockInLocation,
    this.clockOutLocation,
    this.shiftId,
    this.teamId,
    this.scheduledDuration,
    this.actualDuration,
    this.latenessMinutes,
    this.overtimeMinutes,
    this.expectedClockIn,
    this.expectedClockOut,
    this.flags = const [],
    this.requiresJustification = false,
    this.justification,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastModifiedBy,
    this.auditLog = const [],
  }) : date = DateFormat('yyyy-MM-dd').format(clockIn),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'workerId': workerId,
    'clockIn': clockIn.toIso8601String(),
    'clockOut': clockOut?.toIso8601String(),
    'date': date,
    'clockInLocation': clockInLocation?.toMap(),
    'clockOutLocation': clockOutLocation?.toMap(),
    'shiftId': shiftId,
    'teamId': teamId,
    'scheduledDuration': scheduledDuration?.inMinutes,
    'actualDuration': actualDuration?.inMinutes,
    'latenessMinutes': latenessMinutes?.inMinutes,
    'overtimeMinutes': overtimeMinutes?.inMinutes,
    'expectedClockIn': expectedClockIn?.toIso8601String(),
    'expectedClockOut': expectedClockOut?.toIso8601String(),
    'flags': flags.map((f) => f.toString().split('.').last).toList(),
    'requiresJustification': requiresJustification,
    'justification': justification?.toMap(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastModifiedBy': lastModifiedBy,
    'auditLog': auditLog,
  };

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      workerId: map['workerId'] as String,
      clockIn: DateTime.parse(map['clockIn'] as String),
      clockOut:
          map['clockOut'] != null
              ? DateTime.parse(map['clockOut'] as String)
              : null,
      clockInLocation:
          map['clockInLocation'] != null
              ? AttendanceLocation.fromMap(map['clockInLocation'])
              : null,
      clockOutLocation:
          map['clockOutLocation'] != null
              ? AttendanceLocation.fromMap(map['clockOutLocation'])
              : null,
      shiftId: map['shiftId'],
      teamId: map['teamId'],
      scheduledDuration:
          map['scheduledDuration'] != null
              ? Duration(minutes: map['scheduledDuration'])
              : null,
      actualDuration:
          map['actualDuration'] != null
              ? Duration(minutes: map['actualDuration'])
              : null,
      latenessMinutes:
          map['latenessMinutes'] != null
              ? Duration(minutes: map['latenessMinutes'])
              : null,
      overtimeMinutes:
          map['overtimeMinutes'] != null
              ? Duration(minutes: map['overtimeMinutes'])
              : null,
      expectedClockIn:
          map['expectedClockIn'] != null
              ? DateTime.parse(map['expectedClockIn'])
              : null,
      expectedClockOut:
          map['expectedClockOut'] != null
              ? DateTime.parse(map['expectedClockOut'])
              : null,
      flags:
          (map['flags'] as List?)
              ?.map(
                (f) => AttendanceFlag.values.firstWhere(
                  (e) => e.toString().split('.').last == f,
                  orElse: () => AttendanceFlag.suspicious,
                ),
              )
              .toList() ??
          [],
      requiresJustification: map['requiresJustification'] ?? false,
      justification:
          map['justification'] != null
              ? AttendanceJustification.fromMap(map['justification'])
              : null,
      createdAt:
          map['createdAt'] != null
              ? DateTime.parse(map['createdAt'])
              : DateTime.now(),
      updatedAt:
          map['updatedAt'] != null
              ? DateTime.parse(map['updatedAt'])
              : DateTime.now(),
      lastModifiedBy: map['lastModifiedBy'],
      auditLog: List<String>.from(map['auditLog'] ?? []),
    );
  }

  // Analytics methods
  bool get isLate => latenessMinutes != null && latenessMinutes!.inMinutes > 0;
  bool get hasOvertime =>
      overtimeMinutes != null && overtimeMinutes!.inMinutes > 0;
  bool get isClockInFlagged => clockInLocation?.isWithinWorkZone == false;
  bool get isClockOutFlagged => clockOutLocation?.isWithinWorkZone == false;
  bool get hasLocationFlags => isClockInFlagged || isClockOutFlagged;
  bool get hasCriticalFlags => flags.any(
    (flag) => [
      AttendanceFlag.outOfZone,
      AttendanceFlag.suspicious,
      AttendanceFlag.invalidDuration,
    ].contains(flag),
  );
  bool get isComplete => clockOut != null;

  String get workDurationFormatted {
    if (actualDuration == null) return 'N/A';
    final hours = actualDuration!.inHours;
    final minutes = actualDuration!.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String get latenessFormatted {
    if (latenessMinutes == null || latenessMinutes!.inMinutes <= 0) {
      return 'On time';
    }
    final minutes = latenessMinutes!.inMinutes;
    if (minutes < 60) return '${minutes}m late';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m late';
  }

  String get overtimeFormatted {
    if (overtimeMinutes == null || overtimeMinutes!.inMinutes <= 0) {
      return 'No overtime';
    }
    final minutes = overtimeMinutes!.inMinutes;
    if (minutes < 60) return '${minutes}m overtime';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m overtime';
  }

  String get statusSummary {
    if (!isComplete) return 'Active';

    List<String> statusItems = [];
    if (isLate) statusItems.add('Late');
    if (hasOvertime) statusItems.add('Overtime');
    if (hasLocationFlags) statusItems.add('Location Issue');
    if (hasCriticalFlags) statusItems.add('Flagged');
    if (requiresJustification) statusItems.add('Needs Justification');

    return statusItems.isEmpty ? 'Normal' : statusItems.join(', ');
  }

  // Create a copy with updated values
  AttendanceModel copyWith({
    String? workerId,
    DateTime? clockIn,
    DateTime? clockOut,
    AttendanceLocation? clockInLocation,
    AttendanceLocation? clockOutLocation,
    String? shiftId,
    String? teamId,
    Duration? scheduledDuration,
    Duration? actualDuration,
    Duration? latenessMinutes,
    Duration? overtimeMinutes,
    DateTime? expectedClockIn,
    DateTime? expectedClockOut,
    List<AttendanceFlag>? flags,
    bool? requiresJustification,
    AttendanceJustification? justification,
    DateTime? updatedAt,
    String? lastModifiedBy,
    List<String>? auditLog,
  }) {
    return AttendanceModel(
      workerId: workerId ?? this.workerId,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      clockInLocation: clockInLocation ?? this.clockInLocation,
      clockOutLocation: clockOutLocation ?? this.clockOutLocation,
      shiftId: shiftId ?? this.shiftId,
      teamId: teamId ?? this.teamId,
      scheduledDuration: scheduledDuration ?? this.scheduledDuration,
      actualDuration: actualDuration ?? this.actualDuration,
      latenessMinutes: latenessMinutes ?? this.latenessMinutes,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      expectedClockIn: expectedClockIn ?? this.expectedClockIn,
      expectedClockOut: expectedClockOut ?? this.expectedClockOut,
      flags: flags ?? this.flags,
      requiresJustification:
          requiresJustification ?? this.requiresJustification,
      justification: justification ?? this.justification,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      auditLog: auditLog ?? this.auditLog,
    );
  }
}
