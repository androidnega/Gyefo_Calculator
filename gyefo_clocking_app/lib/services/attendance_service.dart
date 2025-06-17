import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/services/location_service.dart';
import 'package:gyefo_clocking_app/services/attendance_analytics_service.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AttendanceAnalyticsService _analyticsService = AttendanceAnalyticsService();
  final ShiftService _shiftService = ShiftService();

  Future<bool> hasClockedInToday(String workerId) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (kDebugMode) {
        print('Checking if worker $workerId has clocked in today: $today');
      }

      // Use the specific collection path instead of collection group
      final snapshot =
          await _firestore
              .collection('attendance')
              .doc(workerId)
              .collection('records')
              .where('date', isEqualTo: today)
              .where(
                'clockOut',
                isNull: true,
              ) // Only check for active (not clocked out) records
              .limit(1)
              .get();

      final hasActiveRecord = snapshot.docs.isNotEmpty;
      if (kDebugMode) {
        print(
          'Worker $workerId has active clock-in for $today: $hasActiveRecord',
        );
      }

      return hasActiveRecord;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking clock status for $workerId: $e');
      }
      return false; // Return false instead of throwing to prevent app crashes
    }
  }  Future<void> clockIn(
    String workerId, {
    Map<String, dynamic>? locationData,
  }) async {
    try {
      final alreadyClockedIn = await hasClockedInToday(workerId);
      if (alreadyClockedIn) {
        throw Exception('Already clocked in today');
      }

      final now = DateTime.now();

      // Create location object if data is provided
      AttendanceLocation? clockInLocation;
      if (locationData != null) {
        clockInLocation = AttendanceLocation(
          latitude: locationData['latitude'] ?? 0.0,
          longitude: locationData['longitude'] ?? 0.0,
          accuracy: locationData['accuracy'] ?? 0.0,
          timestamp: DateTime.now(),
          isWithinWorkZone: locationData['isWithinWorkZone'] ?? false,
          distanceFromWork: locationData['distanceFromWork'],
        );
      }

      // Get user and shift data for analytics
      UserModel? user;
      ShiftModel? shift;
      
      try {
        final userData = await FirestoreService.getUserData(workerId);
        if (userData != null) {
          user = UserModel.fromMap(userData, workerId);
          if (user.shiftId != null) {
            shift = await _shiftService.getShiftById(user.shiftId!);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Could not load user/shift data for analytics: $e');
        }
      }

      // Create initial attendance record
      var newRecord = AttendanceModel(
        workerId: workerId,
        clockIn: now,
        clockInLocation: clockInLocation,
        auditLog: ['${now.toIso8601String()}: Clock-in recorded'],
      );

      // Calculate analytics if shift data is available
      if (shift != null) {
        newRecord = await _analyticsService.calculateAttendanceAnalytics(
          attendance: newRecord,
          shift: shift,
          user: user,
        );
      }

      if (kDebugMode) {
        print('Creating clock-in record for worker: $workerId');
        if (clockInLocation != null) {
          print(
            'Location: ${clockInLocation.latitude}, ${clockInLocation.longitude}',
          );
          print('Within work zone: ${clockInLocation.isWithinWorkZone}');
        }
        if (newRecord.flags.isNotEmpty) {
          print('Flags detected: ${newRecord.flags.map((f) => f.toString().split('.').last).join(', ')}');
        }
      }

      await _firestore
          .collection('attendance')
          .doc(workerId)
          .collection('records')
          .add(newRecord.toMap());

      if (kDebugMode) {
        print(
          'Worker $workerId clocked in successfully at ${now.toIso8601String()}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clocking in for $workerId: $e');
      }
      rethrow;
    }
  }
  Future<void> clockOut(
    String workerId, {
    Map<String, dynamic>? locationData,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (kDebugMode) {
        print('Looking for active clock-in for worker: $workerId on $today');
      }

      // Use the specific collection path instead of collection group
      final snapshot =
          await _firestore
              .collection('attendance')
              .doc(workerId)
              .collection('records')
              .where('date', isEqualTo: today)
              .where('clockOut', isNull: true)
              .orderBy('clockIn', descending: true)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('No active clock-in found for worker $workerId on $today');
        }
        throw Exception('No active clock-in found for today');
      }      final doc = snapshot.docs.first;
      final clockOutTime = DateTime.now();

      // Get current attendance record
      var currentRecord = AttendanceModel.fromMap(doc.data());

      // Create clock-out location if provided
      AttendanceLocation? clockOutLocation;
      if (locationData != null) {
        clockOutLocation = AttendanceLocation(
          latitude: locationData['latitude'] ?? 0.0,
          longitude: locationData['longitude'] ?? 0.0,
          accuracy: locationData['accuracy'] ?? 0.0,
          timestamp: DateTime.now(),
          isWithinWorkZone: locationData['isWithinWorkZone'] ?? false,
          distanceFromWork: locationData['distanceFromWork'],
        );

        if (kDebugMode) {
          print(
            'Clock-out location: ${clockOutLocation.latitude}, ${clockOutLocation.longitude}',
          );
          print('Within work zone: ${clockOutLocation.isWithinWorkZone}');
        }
      }

      // Update record with clock-out time and location
      List<String> auditLog = List.from(currentRecord.auditLog);
      auditLog.add('${clockOutTime.toIso8601String()}: Clock-out recorded');

      var updatedRecord = currentRecord.copyWith(
        clockOut: clockOutTime,
        clockOutLocation: clockOutLocation,
        updatedAt: clockOutTime,
        auditLog: auditLog,
      );

      // Recalculate analytics with clock-out data
      try {
        UserModel? user;
        ShiftModel? shift;
        
        final userData = await FirestoreService.getUserData(workerId);
        if (userData != null) {
          user = UserModel.fromMap(userData, workerId);
          if (user.shiftId != null) {
            shift = await _shiftService.getShiftById(user.shiftId!);
          }
        }

        if (shift != null) {
          updatedRecord = await _analyticsService.calculateAttendanceAnalytics(
            attendance: updatedRecord,
            shift: shift,
            user: user,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Could not recalculate analytics for clock-out: $e');
        }
      }

      if (kDebugMode) {
        print('Updating attendance record with clock-out data');
        if (updatedRecord.flags.isNotEmpty) {
          print('Final flags: ${updatedRecord.flags.map((f) => f.toString().split('.').last).join(', ')}');
        }
        if (updatedRecord.actualDuration != null) {
          print('Work duration: ${updatedRecord.workDurationFormatted}');
        }
      }

      // Update the document with all new data
      await doc.reference.update(updatedRecord.toMap());

      if (kDebugMode) {
        print(
          'Worker $workerId clocked out successfully at ${clockOutTime.toIso8601String()}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clocking out for $workerId: $e');
      }
      rethrow;
    }
  }

  // Helper method to get today's active record
  Future<Map<String, dynamic>?> getTodayActiveRecord(String workerId) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final snapshot =
          await _firestore
              .collection('attendance')
              .doc(workerId)
              .collection('records')
              .where('date', isEqualTo: today)
              .where('clockOut', isNull: true)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting today\'s active record for $workerId: $e');
      }
      return null;
    }
  }

  /// Get worker attendance records with optional date range filtering
  Future<List<AttendanceModel>> getWorkerAttendanceRecords({
    required String workerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      if (kDebugMode) {
        print('Fetching attendance records for worker: $workerId');
        if (fromDate != null) {
          print('From date: ${DateFormat('yyyy-MM-dd').format(fromDate)}');
        }
        if (toDate != null) {
          print('To date: ${DateFormat('yyyy-MM-dd').format(toDate)}');
        }
      }

      Query query = _firestore
          .collection('attendance')
          .doc(workerId)
          .collection('records')
          .orderBy('clockIn', descending: true);

      // Apply date range filters if provided
      if (fromDate != null) {
        final fromDateString = DateFormat('yyyy-MM-dd').format(fromDate);
        query = query.where('date', isGreaterThanOrEqualTo: fromDateString);
      }

      if (toDate != null) {
        final toDateString = DateFormat('yyyy-MM-dd').format(toDate);
        query = query.where('date', isLessThanOrEqualTo: toDateString);
      }

      final snapshot = await query.get();
      final records =
          snapshot.docs
              .map(
                (doc) =>
                    AttendanceModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();

      if (kDebugMode) {
        print(
          'Found ${records.length} attendance records for worker: $workerId',
        );
      }

      return records;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching attendance records for $workerId: $e');
      }
      return [];
    }
  }

  /// Get attendance records for a specific date
  Future<List<AttendanceModel>> getWorkerAttendanceForDate({
    required String workerId,
    required DateTime date,
  }) async {
    return getWorkerAttendanceRecords(
      workerId: workerId,
      fromDate: date,
      toDate: date,
    );
  }

  /// Get attendance records for the last N days
  Future<List<AttendanceModel>> getWorkerAttendanceLastDays({
    required String workerId,
    required int days,
  }) async {
    final toDate = DateTime.now();
    final fromDate = toDate.subtract(Duration(days: days));

    return getWorkerAttendanceRecords(
      workerId: workerId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  /// Get attendance records for the current month
  Future<List<AttendanceModel>> getWorkerAttendanceThisMonth({
    required String workerId,
  }) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    return getWorkerAttendanceRecords(
      workerId: workerId,
      fromDate: firstDayOfMonth,
      toDate: lastDayOfMonth,
    );
  }

  /// Get attendance records for the current week
  Future<List<AttendanceModel>> getWorkerAttendanceThisWeek({
    required String workerId,
  }) async {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    return getWorkerAttendanceRecords(
      workerId: workerId,
      fromDate: firstDayOfWeek,
      toDate: lastDayOfWeek,
    );
  }

  /// Enhanced clock-in with zone validation
  Future<ClockResult> clockInWithZoneValidation(String workerId) async {
    try {
      final alreadyClockedIn = await hasClockedInToday(workerId);
      if (alreadyClockedIn) {
        return ClockResult(
          success: false,
          message: 'Already clocked in today',
          requiresManagerOverride: false,
        );
      }

      // Perform zone validation
      final zoneValidation = await LocationService.validateZoneLocation();

      if (kDebugMode) {
        print('Zone validation result for $workerId:');
        print('  - Within zone: ${zoneValidation.isWithinZone}');
        print('  - Message: ${zoneValidation.message}');
        if (zoneValidation.distance != null) {
          print('  - Distance: ${zoneValidation.formattedDistance}');
        }
      }

      final now = DateTime.now();

      // Create location object from zone validation
      AttendanceLocation? clockInLocation;
      if (zoneValidation.hasLocationData) {
        clockInLocation = AttendanceLocation(
          latitude: zoneValidation.currentPosition!.latitude,
          longitude: zoneValidation.currentPosition!.longitude,
          accuracy: zoneValidation.currentPosition!.accuracy,
          timestamp: now,
          isWithinWorkZone: zoneValidation.isWithinZone,
          distanceFromWork: zoneValidation.distance,
        );
      }

      final newRecord = AttendanceModel(
        workerId: workerId,
        clockIn: now,
        clockInLocation: clockInLocation,
      );

      // Save the record regardless of zone validation
      await _firestore
          .collection('attendance')
          .doc(workerId)
          .collection('records')
          .add(newRecord.toMap());

      if (kDebugMode) {
        print('Worker $workerId clocked in at ${now.toIso8601String()}');
        if (clockInLocation != null) {
          print(
            'Location: ${clockInLocation.latitude}, ${clockInLocation.longitude}',
          );
          print('Within work zone: ${clockInLocation.isWithinWorkZone}');
        }
      }

      // If not within zone, flag for manager review
      if (!zoneValidation.isWithinZone && zoneValidation.distance != null) {
        await _flagAttendanceForReview(
          workerId: workerId,
          reason: 'Clock-in outside work zone',
          details: zoneValidation.message,
          attendanceDate: DateFormat('yyyy-MM-dd').format(now),
        );

        return ClockResult(
          success: true,
          message: 'Clocked in successfully. ${zoneValidation.message}',
          requiresManagerOverride: true,
          locationValidation: zoneValidation,
        );
      }

      return ClockResult(
        success: true,
        message: 'Clocked in successfully. ${zoneValidation.message}',
        requiresManagerOverride: false,
        locationValidation: zoneValidation,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error clocking in for $workerId: $e');
      }
      return ClockResult(
        success: false,
        message: 'Error clocking in: $e',
        requiresManagerOverride: false,
      );
    }
  }

  /// Enhanced clock-out with zone validation
  Future<ClockResult> clockOutWithZoneValidation(String workerId) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Check for active clock-in
      final snapshot =
          await _firestore
              .collection('attendance')
              .doc(workerId)
              .collection('records')
              .where('date', isEqualTo: today)
              .where('clockOut', isNull: true)
              .orderBy('clockIn', descending: true)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return ClockResult(
          success: false,
          message: 'No active clock-in found for today',
          requiresManagerOverride: false,
        );
      }

      // Perform zone validation
      final zoneValidation = await LocationService.validateZoneLocation();

      if (kDebugMode) {
        print('Zone validation for clock-out by $workerId:');
        print('  - Within zone: ${zoneValidation.isWithinZone}');
        print('  - Message: ${zoneValidation.message}');
        if (zoneValidation.distance != null) {
          print('  - Distance: ${zoneValidation.formattedDistance}');
        }
      }

      final doc = snapshot.docs.first;
      final clockOutTime = DateTime.now();

      // Prepare update data
      Map<String, dynamic> updateData = {
        'clockOut': clockOutTime.toIso8601String(),
      };

      // Add clock-out location from zone validation
      if (zoneValidation.hasLocationData) {
        final clockOutLocation = AttendanceLocation(
          latitude: zoneValidation.currentPosition!.latitude,
          longitude: zoneValidation.currentPosition!.longitude,
          accuracy: zoneValidation.currentPosition!.accuracy,
          timestamp: clockOutTime,
          isWithinWorkZone: zoneValidation.isWithinZone,
          distanceFromWork: zoneValidation.distance,
        );

        updateData['clockOutLocation'] = clockOutLocation.toMap();

        if (kDebugMode) {
          print(
            'Clock-out location: ${clockOutLocation.latitude}, ${clockOutLocation.longitude}',
          );
          print('Within work zone: ${clockOutLocation.isWithinWorkZone}');
        }
      }

      await doc.reference.update(updateData);

      if (kDebugMode) {
        print(
          'Worker $workerId clocked out at ${clockOutTime.toIso8601String()}',
        );
      }

      // If not within zone, flag for manager review
      if (!zoneValidation.isWithinZone && zoneValidation.distance != null) {
        await _flagAttendanceForReview(
          workerId: workerId,
          reason: 'Clock-out outside work zone',
          details: zoneValidation.message,
          attendanceDate: today,
        );

        return ClockResult(
          success: true,
          message: 'Clocked out successfully. ${zoneValidation.message}',
          requiresManagerOverride: true,
          locationValidation: zoneValidation,
        );
      }

      return ClockResult(
        success: true,
        message: 'Clocked out successfully. ${zoneValidation.message}',
        requiresManagerOverride: false,
        locationValidation: zoneValidation,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error clocking out for $workerId: $e');
      }
      return ClockResult(
        success: false,
        message: 'Error clocking out: $e',
        requiresManagerOverride: false,
      );
    }
  }

  /// Flag attendance record for manager review
  Future<void> _flagAttendanceForReview({
    required String workerId,
    required String reason,
    required String details,
    required String attendanceDate,
  }) async {
    try {
      await _firestore.collection('flaggedAttendance').add({
        'workerId': workerId,
        'reason': reason,
        'details': details,
        'attendanceDate': attendanceDate,
        'flaggedAt': Timestamp.now(),
        'isResolved': false,
        'reviewedBy': null,
        'reviewNotes': null,
      });

      if (kDebugMode) {
        print('Flagged attendance for review: $workerId - $reason');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error flagging attendance for review: $e');
      }
    }
  }
}

/// Result class for clock-in/out operations with zone validation
class ClockResult {
  final bool success;
  final String message;
  final bool requiresManagerOverride;
  final ZoneValidationResult? locationValidation;

  ClockResult({
    required this.success,
    required this.message,
    required this.requiresManagerOverride,
    this.locationValidation,
  });

  /// Whether the operation was completed but flagged for review
  bool get isFlagged => success && requiresManagerOverride;

  /// Whether location validation passed
  bool get isLocationValid => locationValidation?.isWithinZone ?? true;

  /// Formatted distance from work zone
  String get distanceFromZone => locationValidation?.formattedDistance ?? 'N/A';

  /// Zone validation message
  String get locationMessage =>
      locationValidation?.message ?? 'Location validation not performed';
}
