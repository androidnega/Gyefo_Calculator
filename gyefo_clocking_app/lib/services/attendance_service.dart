import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  Future<void> clockIn(String workerId, {Map<String, dynamic>? locationData}) async {
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
      
      final newRecord = AttendanceModel(
        workerId: workerId, 
        clockIn: now,
        clockInLocation: clockInLocation,
      );

      if (kDebugMode) {
        print('Creating clock-in record for worker: $workerId');
        if (clockInLocation != null) {
          print('Location: ${clockInLocation.latitude}, ${clockInLocation.longitude}');
          print('Within work zone: ${clockInLocation.isWithinWorkZone}');
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
  Future<void> clockOut(String workerId, {Map<String, dynamic>? locationData}) async {
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
      
      // Prepare update data
      Map<String, dynamic> updateData = {
        'clockOut': clockOutTime.toIso8601String(),
      };
      
      // Add clock-out location if provided
      if (locationData != null) {
        final clockOutLocation = AttendanceLocation(
          latitude: locationData['latitude'] ?? 0.0,
          longitude: locationData['longitude'] ?? 0.0,
          accuracy: locationData['accuracy'] ?? 0.0,
          timestamp: DateTime.now(),
          isWithinWorkZone: locationData['isWithinWorkZone'] ?? false,
          distanceFromWork: locationData['distanceFromWork'],
        );
        
        updateData['clockOutLocation'] = clockOutLocation.toMap();
        
        if (kDebugMode) {
          print('Clock-out location: ${clockOutLocation.latitude}, ${clockOutLocation.longitude}');
          print('Within work zone: ${clockOutLocation.isWithinWorkZone}');
        }
      }

      await doc.reference.update(updateData);

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
}
