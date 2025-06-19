import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';

class ShiftEnforcementService {
  final ShiftService _shiftService = ShiftService();

  /// Check if a worker can clock in/out based on their shift schedule
  Future<ShiftEnforcementResult> canPerformClockAction({
    required String workerId,
    required ClockAction action,
    DateTime? clockTime,
  }) async {
    try {
      clockTime ??= DateTime.now();

      // Get worker details
      final userData = await FirestoreService.getUserData(workerId);
      if (userData == null) {
        return ShiftEnforcementResult.denied(
          'Worker data not found',
        );
      }

      final user = UserModel.fromMap(userData, workerId);

      // If no shift assigned, allow clocking (legacy support)
      if (user.shiftId == null || user.shiftId!.isEmpty) {
        if (kDebugMode) {
          print('No shift assigned to worker, allowing clock action');
        }
        return ShiftEnforcementResult.allowed();
      }

      // Get shift details
      final shift = await _shiftService.getShiftById(user.shiftId!);
      if (shift == null) {
        return ShiftEnforcementResult.denied(
          'Invalid shift assignment. Please contact your manager.',
        );
      }

      // Check if shift is active
      if (!shift.isActive) {
        return ShiftEnforcementResult.denied(
          'Your assigned shift is currently inactive. Please contact your manager.',
        );
      }

      // Check work day
      if (!shift.isWorkDay(clockTime)) {
        return ShiftEnforcementResult.denied(
          'Today is not a working day according to your shift schedule.',
        );
      }

      // Check time constraints
      final timeValidation = _validateShiftTime(shift, clockTime, action);
      return timeValidation;

    } catch (e) {
      if (kDebugMode) {
        print('Error in shift enforcement: $e');
      }
      return ShiftEnforcementResult.denied(
        'Unable to verify shift schedule. Please try again.',
      );
    }
  }

  /// Validate if the clock time is within shift constraints
  ShiftEnforcementResult _validateShiftTime(
    ShiftModel shift,
    DateTime clockTime,
    ClockAction action,
  ) {
    final timeOfDay = TimeOfDay.fromDateTime(clockTime);
    final shiftStart = _parseTimeOfDay(shift.startTime);
    final shiftEnd = _parseTimeOfDay(shift.endTime);

    // Handle overnight shifts (e.g., 22:00 - 06:00)
    final isOvernightShift = shiftEnd.hour < shiftStart.hour ||
        (shiftEnd.hour == shiftStart.hour && shiftEnd.minute < shiftStart.minute);

    if (action == ClockAction.clockIn) {
      return _validateClockInTime(shift, timeOfDay, shiftStart, shiftEnd, isOvernightShift);
    } else {
      return _validateClockOutTime(shift, timeOfDay, shiftStart, shiftEnd, isOvernightShift);
    }
  }

  /// Validate clock-in time
  ShiftEnforcementResult _validateClockInTime(
    ShiftModel shift,
    TimeOfDay currentTime,
    TimeOfDay shiftStart,
    TimeOfDay shiftEnd,
    bool isOvernightShift,
  ) {
    // Calculate grace period window
    final graceStart = _subtractMinutes(shiftStart, shift.gracePeriodMinutes);
    final graceEnd = _addMinutes(shiftStart, shift.gracePeriodMinutes);

    // For overnight shifts, we need special handling
    if (isOvernightShift) {
      // Check if current time is in the clock-in window
      // Grace period before shift start OR after midnight for overnight shifts
      final isInGracePeriod = _isTimeInRange(currentTime, graceStart, TimeOfDay(hour: 23, minute: 59)) ||
          _isTimeInRange(currentTime, TimeOfDay(hour: 0, minute: 0), graceEnd);
      
      if (isInGracePeriod) {
        return ShiftEnforcementResult.allowed();
      }
    } else {
      // Normal day shift
      if (_isTimeInRange(currentTime, graceStart, graceEnd)) {
        return ShiftEnforcementResult.allowed();
      }
    }

    // Calculate how far off they are
    final shiftStartMinutes = shiftStart.hour * 60 + shiftStart.minute;
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;
    final difference = currentMinutes - shiftStartMinutes;

    if (difference < -shift.gracePeriodMinutes) {
      final minutesEarly = -difference;      return ShiftEnforcementResult.denied(
        'You\'re trying to clock in $minutesEarly minutes too early. '
        'Your shift starts at ${shift.startTime} with a ${shift.gracePeriodMinutes}-minute grace period.',
      );
    } else if (difference > shift.gracePeriodMinutes) {
      final minutesLate = difference;      return ShiftEnforcementResult.denied(
        'You\'re trying to clock in $minutesLate minutes after your grace period ended. '
        'Please contact your manager for assistance.',
      );
    }

    return ShiftEnforcementResult.allowed();
  }

  /// Validate clock-out time
  ShiftEnforcementResult _validateClockOutTime(
    ShiftModel shift,
    TimeOfDay currentTime,
    TimeOfDay shiftStart,
    TimeOfDay shiftEnd,
    bool isOvernightShift,
  ) {
    // For clock-out, we're more lenient
    // Check if it's reasonable clock-out time (not too early, overtime allowed if configured)

    if (isOvernightShift) {
      // For overnight shifts, allow clock-out from shift start time until end time (next day)
      final canClockOut = _isTimeInRange(currentTime, shiftStart, TimeOfDay(hour: 23, minute: 59)) ||
          _isTimeInRange(currentTime, TimeOfDay(hour: 0, minute: 0), shiftEnd);
      
      if (canClockOut) {
        return ShiftEnforcementResult.allowed();
      }
    } else {
      // Normal day shift - allow clock-out from shift start until reasonable time
      final earliestClockOut = _addMinutes(shiftStart, 30); // At least 30 minutes after start
      final latestClockOut = shift.allowOvertime
          ? _addMinutes(shiftEnd, 180) // Up to 3 hours overtime if allowed
          : _addMinutes(shiftEnd, 30); // 30 minutes after shift end

      if (_isTimeInRange(currentTime, earliestClockOut, latestClockOut)) {
        return ShiftEnforcementResult.allowed();
      }

      // Check if it's too early
      if (_isTimeBefore(currentTime, earliestClockOut)) {
        return ShiftEnforcementResult.denied(
          'You cannot clock out within 30 minutes of starting your shift.',
        );
      }

      // Check if it's too late and overtime not allowed
      if (!shift.allowOvertime && _isTimeAfter(currentTime, _addMinutes(shiftEnd, 30))) {
        return ShiftEnforcementResult.denied(
          'Overtime is not allowed for your shift. Please contact your manager.',
        );
      }
    }

    return ShiftEnforcementResult.allowed();
  }

  /// Parse time string (HH:mm) to TimeOfDay
  TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  /// Add minutes to TimeOfDay
  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  /// Subtract minutes from TimeOfDay
  TimeOfDay _subtractMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute - minutes;
    if (totalMinutes < 0) {
      final adjustedMinutes = totalMinutes + (24 * 60);
      return TimeOfDay(
        hour: adjustedMinutes ~/ 60,
        minute: adjustedMinutes % 60,
      );
    }
    return TimeOfDay(
      hour: totalMinutes ~/ 60,
      minute: totalMinutes % 60,
    );
  }

  /// Check if time is within range (inclusive)
  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return timeMinutes >= startMinutes && timeMinutes <= endMinutes;
  }

  /// Check if time is before another time
  bool _isTimeBefore(TimeOfDay time, TimeOfDay other) {
    final timeMinutes = time.hour * 60 + time.minute;
    final otherMinutes = other.hour * 60 + other.minute;
    return timeMinutes < otherMinutes;
  }

  /// Check if time is after another time
  bool _isTimeAfter(TimeOfDay time, TimeOfDay other) {
    final timeMinutes = time.hour * 60 + time.minute;
    final otherMinutes = other.hour * 60 + other.minute;
    return timeMinutes > otherMinutes;
  }

  /// Get shift info for display
  Future<String?> getWorkerShiftInfo(String workerId) async {
    try {
      final userData = await FirestoreService.getUserData(workerId);
      if (userData == null) return null;

      final user = UserModel.fromMap(userData, workerId);
      if (user.shiftId == null) return 'No shift assigned';

      final shift = await _shiftService.getShiftById(user.shiftId!);
      if (shift == null) return 'Invalid shift';

      return '${shift.name} (${shift.startTime} - ${shift.endTime})';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting shift info: $e');
      }
      return null;
    }
  }
}

enum ClockAction { clockIn, clockOut }

class ShiftEnforcementResult {
  final bool isAllowed;
  final String? denialReason;

  ShiftEnforcementResult._(this.isAllowed, this.denialReason);

  factory ShiftEnforcementResult.allowed() {
    return ShiftEnforcementResult._(true, null);
  }

  factory ShiftEnforcementResult.denied(String reason) {
    return ShiftEnforcementResult._(false, reason);
  }
}
