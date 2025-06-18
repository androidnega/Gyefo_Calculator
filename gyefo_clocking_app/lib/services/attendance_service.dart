import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/services/location_service.dart';
import 'package:gyefo_clocking_app/services/attendance_analytics_service.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';
import 'package:gyefo_clocking_app/services/simple_notification_service.dart';
import 'package:gyefo_clocking_app/services/manager_notification_service.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AttendanceAnalyticsService _analyticsService =
      AttendanceAnalyticsService();
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
  }

  Future<void> clockIn(
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

      // Validate shift compliance
      final shiftCompliance = await validateShiftCompliance(
        workerId,
        now,
        'clock_in',
      );
      if (shiftCompliance['flags'].isNotEmpty) {
        // Add shift compliance flags to the record
        final existingFlags = newRecord.flags.toList();
        for (final flag in shiftCompliance['flags']) {
          switch (flag) {
            case 'late':
              existingFlags.add(AttendanceFlag.late);
              break;
            case 'non_working_day':
              existingFlags.add(AttendanceFlag.nonWorkingDay);
              break;
          }
        }

        // Add compliance reasons to audit log
        final auditLog = newRecord.auditLog.toList();
        for (final reason in shiftCompliance['reasons']) {
          auditLog.add('${now.toIso8601String()}: Shift compliance: $reason');
        }

        newRecord = newRecord.copyWith(
          flags: existingFlags,
          auditLog: auditLog,
        );
      }

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
          print(
            'Flags detected: ${newRecord.flags.map((f) => f.toString().split('.').last).join(', ')}',
          );
        }
      }
      await _firestore
          .collection('attendance')
          .doc(workerId)
          .collection('records')
          .add(newRecord.toMap());

      // Send notification for successful clock-in
      await SimpleNotificationService.showLocalNotification(
        title: 'Clock-in Successful',
        body:
            'You have successfully clocked in at ${DateFormat('h:mm a').format(now)}',
      );

      // Create manager notification for clock-in (especially if flagged)
      if (user != null) {
        // Get manager ID - for now using a placeholder, should be from company/team structure
        final managerId = await _getManagerId(workerId);
        if (managerId != null) {
          // Always notify for flagged attendance, optionally for successful clock-ins
          if (newRecord.flags.isNotEmpty) {
            final flagReasons = newRecord.flags
                .map((f) => f.toString().split('.').last)
                .join(', ');
            await NotificationService.createFlaggedAttendanceNotification(
              managerId: managerId,
              workerName: user.name,
              workerId: workerId,
              attendanceId: newRecord.date, // Using date as ID for now
              reason: flagReasons,
            );
          } else {
            // Optional: Create low-priority notification for successful clock-ins
            await NotificationService.createClockSuccessNotification(
              managerId: managerId,
              workerName: user.name,
              workerId: workerId,
              attendanceId: newRecord.date,
              action: 'clock_in',
            );
          }
        }
      }

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
      }
      final doc = snapshot.docs.first;
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

      // Validate shift compliance for clock-out
      final shiftCompliance = await validateShiftCompliance(
        workerId,
        clockOutTime,
        'clock_out',
      );
      if (shiftCompliance['flags'].isNotEmpty) {
        // Add shift compliance flags to the record
        final existingFlags = updatedRecord.flags.toList();
        for (final flag in shiftCompliance['flags']) {
          switch (flag) {
            case 'early_departure':
              existingFlags.add(AttendanceFlag.earlyClockOut);
              break;
            case 'unauthorized_overtime':
              existingFlags.add(AttendanceFlag.unauthorizedOvertime);
              break;
            case 'non_working_day':
              existingFlags.add(AttendanceFlag.nonWorkingDay);
              break;
          }
        }

        // Add compliance reasons to audit log
        final complianceAuditLog = updatedRecord.auditLog.toList();
        for (final reason in shiftCompliance['reasons']) {
          complianceAuditLog.add(
            '${clockOutTime.toIso8601String()}: Shift compliance: $reason',
          );
        }

        updatedRecord = updatedRecord.copyWith(
          flags: existingFlags,
          auditLog: complianceAuditLog,
        );
      }

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
          print(
            'Final flags: ${updatedRecord.flags.map((f) => f.toString().split('.').last).join(', ')}',
          );
        }
        if (updatedRecord.actualDuration != null) {
          print('Work duration: ${updatedRecord.workDurationFormatted}');
        }
      }

      // Update the document with all new data
      await doc.reference.update(updatedRecord.toMap());

      // Send notification for successful clock-out
      await SimpleNotificationService.showLocalNotification(
        title: 'Clock-out Successful',
        body:
            'You have successfully clocked out at ${DateFormat('h:mm a').format(clockOutTime)}',
      );

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

  /// Validate shift compliance for attendance events
  Future<Map<String, dynamic>> validateShiftCompliance(
    String workerId,
    DateTime clockTime,
    String eventType, // 'clock_in' or 'clock_out'
  ) async {
    final flags = <String>[];
    final reasons = <String>[];

    try {
      // Get worker details
      final userDoc = await _firestore.collection('users').doc(workerId).get();
      if (!userDoc.exists) {
        return {'flags': flags, 'reasons': reasons};
      }

      final userData = userDoc.data()!;
      final shiftId = userData['shiftId'] as String?;

      // If no shift assigned, skip validation
      if (shiftId == null) {
        return {'flags': flags, 'reasons': reasons};
      }

      // Get shift details
      final shift = await _shiftService.getShiftById(shiftId);
      if (shift == null) {
        return {'flags': flags, 'reasons': reasons};
      }

      // Check if working on non-scheduled day (including weekends)
      if (_shiftService.isNonScheduledDay(shift, clockTime)) {
        flags.add('non_working_day');
        if (_shiftService.isWeekend(clockTime)) {
          reasons.add('Worked on weekend when not allowed');
        } else {
          reasons.add('Worked on non-scheduled day');
        }
      }

      // Validate clock-in specific rules
      if (eventType == 'clock_in') {
        if (_shiftService.isLateClockIn(shift, clockTime)) {
          flags.add('late');
          final gracePeriodEnd = _shiftService.getGracePeriodEnd(
            shift,
            clockTime,
          );
          final minutesLate = clockTime.difference(gracePeriodEnd).inMinutes;
          reasons.add('Clock-in $minutesLate minutes after grace period');
        }
      }

      // Validate clock-out specific rules
      if (eventType == 'clock_out') {
        if (_shiftService.isEarlyClockOut(shift, clockTime)) {
          flags.add('early_departure');
          final shiftEnd = _shiftService.parseShiftEndTime(shift, clockTime);
          final minutesEarly = shiftEnd.difference(clockTime).inMinutes;
          reasons.add('Clock-out $minutesEarly minutes before shift end');
        }

        if (_shiftService.isUnauthorizedOvertime(shift, clockTime)) {
          flags.add('unauthorized_overtime');
          final shiftEnd = _shiftService.parseShiftEndTime(shift, clockTime);
          final overtimeMinutes = clockTime.difference(shiftEnd).inMinutes;
          reasons.add('Unauthorized overtime: $overtimeMinutes minutes');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error validating shift compliance: $e');
      }
    }
    return {'flags': flags, 'reasons': reasons};
  }

  /// Helper method to get manager ID for a worker
  /// In a real app, this would be based on team/company structure
  Future<String?> _getManagerId(String workerId) async {
    try {
      // For now, get all users with 'manager' role
      // In a real app, this should be based on team assignments or company hierarchy
      final managersSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'manager')
              .limit(1)
              .get();

      if (managersSnapshot.docs.isNotEmpty) {
        return managersSnapshot.docs.first.id;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting manager ID: $e');
      }
      return null;
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
