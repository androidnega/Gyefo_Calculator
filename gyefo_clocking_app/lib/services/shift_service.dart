import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class ShiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all shifts
  Future<List<ShiftModel>> getAllShifts() async {
    try {
      final snapshot =
          await _firestore
              .collection('shifts')
              .where('isActive', isEqualTo: true)
              .orderBy('name')
              .get();

      return snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching shifts: $e');
      return [];
    }
  }

  /// Get shift by ID
  Future<ShiftModel?> getShiftById(String shiftId) async {
    try {
      final doc = await _firestore.collection('shifts').doc(shiftId).get();
      if (doc.exists) {
        return ShiftModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching shift $shiftId: $e');
      return null;
    }
  }

  /// Create new shift
  Future<String?> createShift(ShiftModel shift) async {
    try {
      final docRef = await _firestore.collection('shifts').add(shift.toMap());
      AppLogger.success('Shift created successfully: ${shift.name}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error creating shift: $e');
      return null;
    }
  }

  /// Update shift
  Future<bool> updateShift(ShiftModel shift) async {
    try {
      await _firestore.collection('shifts').doc(shift.id).update(shift.toMap());
      AppLogger.success('Shift updated successfully: ${shift.name}');
      return true;
    } catch (e) {
      AppLogger.error('Error updating shift: $e');
      return false;
    }
  }

  /// Delete shift
  Future<bool> deleteShift(String shiftId) async {
    try {
      await _firestore.collection('shifts').doc(shiftId).delete();
      AppLogger.success('Shift deleted successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error deleting shift: $e');
      return false;
    }
  }

  /// Check if worker is late for their shift
  Future<bool> isWorkerLate(String workerId, DateTime clockInTime) async {
    try {
      // Get worker's shift information
      final userDoc = await _firestore.collection('users').doc(workerId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final shiftId = userData['shiftId'] as String?;
      if (shiftId == null) return false;

      final shift = await getShiftById(shiftId);
      if (shift == null) return false;

      // Check if today is a work day
      if (!shift.isWorkDay(clockInTime)) return false;

      // Parse shift start time
      final startTimeParts = shift.startTime.split(':');
      final shiftStart = DateTime(
        clockInTime.year,
        clockInTime.month,
        clockInTime.day,
        int.parse(startTimeParts[0]),
        int.parse(startTimeParts[1]),
      );

      // Add grace period
      final graceEnd = shiftStart.add(
        Duration(minutes: shift.gracePeriodMinutes),
      );

      return clockInTime.isAfter(graceEnd);
    } catch (e) {
      AppLogger.error('Error checking if worker is late: $e');
      return false;
    }
  }

  /// Calculate overtime for worker
  Future<int> calculateOvertime(String workerId, DateTime clockOutTime) async {
    try {
      // Get worker's shift information
      final userDoc = await _firestore.collection('users').doc(workerId).get();
      if (!userDoc.exists) return 0;

      final userData = userDoc.data()!;
      final shiftId = userData['shiftId'] as String?;
      if (shiftId == null) return 0;

      final shift = await getShiftById(shiftId);
      if (shift == null) return 0;

      // Parse shift end time
      final endTimeParts = shift.endTime.split(':');
      final shiftEnd = DateTime(
        clockOutTime.year,
        clockOutTime.month,
        clockOutTime.day,
        int.parse(endTimeParts[0]),
        int.parse(endTimeParts[1]),
      );

      if (clockOutTime.isAfter(shiftEnd)) {
        return clockOutTime.difference(shiftEnd).inMinutes;
      }

      return 0;
    } catch (e) {
      AppLogger.error('Error calculating overtime: $e');
      return 0;
    }
  }

  /// Get shift schedule for display
  String getShiftScheduleText(ShiftModel shift) {
    return '${shift.startTime} - ${shift.endTime} (${shift.workDaysString})';
  }

  /// Stream of shifts for real-time updates
  Stream<List<ShiftModel>> shiftsStream() {
    return _firestore
        .collection('shifts')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Parse shift start time as DateTime for given date
  DateTime parseShiftStartTime(ShiftModel shift, DateTime date) {
    final startTimeParts = shift.startTime.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(startTimeParts[0]),
      int.parse(startTimeParts[1]),
    );
  }

  /// Parse shift end time as DateTime for given date
  DateTime parseShiftEndTime(ShiftModel shift, DateTime date) {
    final endTimeParts = shift.endTime.split(':');
    var endDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(endTimeParts[0]),
      int.parse(endTimeParts[1]),
    );

    // Handle overnight shifts (end time is next day)
    final startDateTime = parseShiftStartTime(shift, date);
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    return endDateTime;
  }

  /// Check if today is a weekend
  bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Check if date is a work day according to shift
  bool isWorkDay(ShiftModel shift, DateTime date) {
    if (isWeekend(date) && !shift.allowWeekends) {
      return false;
    }
    return shift.workDays.contains(date.weekday);
  }

  /// Get grace period end time for shift
  DateTime getGracePeriodEnd(ShiftModel shift, DateTime date) {
    final shiftStart = parseShiftStartTime(shift, date);
    return shiftStart.add(Duration(minutes: shift.gracePeriodMinutes));
  }

  /// Check if worker is late based on shift rules
  bool isLateClockIn(ShiftModel shift, DateTime clockInTime) {
    if (!isWorkDay(shift, clockInTime)) return false;

    final gracePeriodEnd = getGracePeriodEnd(shift, clockInTime);
    return clockInTime.isAfter(gracePeriodEnd);
  }

  /// Check if clock-out is early
  bool isEarlyClockOut(ShiftModel shift, DateTime clockOutTime) {
    if (!isWorkDay(shift, clockOutTime)) return false;

    final shiftEnd = parseShiftEndTime(shift, clockOutTime);
    return clockOutTime.isBefore(shiftEnd);
  }

  /// Check if clock-out is unauthorized overtime
  bool isUnauthorizedOvertime(ShiftModel shift, DateTime clockOutTime) {
    if (!isWorkDay(shift, clockOutTime) || shift.allowOvertime) return false;

    final shiftEnd = parseShiftEndTime(shift, clockOutTime);
    return clockOutTime.isAfter(shiftEnd);
  }

  /// Check if working on non-scheduled day
  bool isNonScheduledDay(ShiftModel shift, DateTime date) {
    return !isWorkDay(shift, date);
  }
}
