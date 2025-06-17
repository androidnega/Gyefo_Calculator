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

class AttendanceModel {
  final String workerId;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String date;
  final AttendanceLocation? clockInLocation;
  final AttendanceLocation? clockOutLocation;

  AttendanceModel({
    required this.workerId,
    required this.clockIn,
    this.clockOut,
    this.clockInLocation,
    this.clockOutLocation,
  }) : date = DateFormat('yyyy-MM-dd').format(clockIn);

  Map<String, dynamic> toMap() => {
    'workerId': workerId,
    'clockIn': clockIn.toIso8601String(),
    'clockOut': clockOut?.toIso8601String(),
    'date': date,
    'clockInLocation': clockInLocation?.toMap(),
    'clockOutLocation': clockOutLocation?.toMap(),
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
    );
  }

  /// Check if clock-in was made outside work zone
  bool get isClockInFlagged => clockInLocation?.isWithinWorkZone == false;

  /// Check if clock-out was made outside work zone
  bool get isClockOutFlagged => clockOutLocation?.isWithinWorkZone == false;

  /// Check if any location is flagged
  bool get hasLocationFlags => isClockInFlagged || isClockOutFlagged;
}
