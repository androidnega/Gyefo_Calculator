import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:intl/intl.dart';

class AttendanceAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate attendance analytics based on shift schedule
  Future<AttendanceModel> calculateAttendanceAnalytics({
    required AttendanceModel attendance,
    ShiftModel? shift,
    UserModel? user,
  }) async {
    try {
      if (shift == null) {
        if (kDebugMode) {
          print('No shift data available for analytics calculation');
        }
        return attendance;
      }

      // Parse shift times for the attendance date
      final attendanceDate = attendance.clockIn;
      final expectedClockIn = _parseShiftDateTime(attendanceDate, shift.startTime);
      final expectedClockOut = _parseShiftDateTime(attendanceDate, shift.endTime);
      
      // Calculate scheduled duration
      final scheduledDuration = expectedClockOut.difference(expectedClockIn);
      
      // Calculate lateness
      Duration? latenessMinutes;
      final gracePeriod = Duration(minutes: shift.gracePeriodMinutes);
      final clockInWithGrace = expectedClockIn.add(gracePeriod);
      
      if (attendance.clockIn.isAfter(clockInWithGrace)) {
        latenessMinutes = attendance.clockIn.difference(expectedClockIn);
      }

      // Calculate actual duration and overtime (only if clocked out)
      Duration? actualDuration;
      Duration? overtimeMinutes;
      
      if (attendance.clockOut != null) {
        actualDuration = attendance.clockOut!.difference(attendance.clockIn);
        
        // Calculate overtime (work beyond expected clock out)
        if (attendance.clockOut!.isAfter(expectedClockOut)) {
          overtimeMinutes = attendance.clockOut!.difference(expectedClockOut);
        }
      }

      // Determine flags
      List<AttendanceFlag> flags = [];
      bool requiresJustification = false;

      // Location flags
      if (attendance.clockInLocation?.isWithinWorkZone == false) {
        flags.add(AttendanceFlag.outOfZone);
        requiresJustification = true;
      }
      if (attendance.clockOutLocation?.isWithinWorkZone == false) {
        flags.add(AttendanceFlag.outOfZone);
        requiresJustification = true;
      }

      // Lateness flag
      if (latenessMinutes != null && latenessMinutes.inMinutes > shift.gracePeriodMinutes) {
        flags.add(AttendanceFlag.late);
        if (latenessMinutes.inMinutes > 30) { // Late by more than 30 minutes
          requiresJustification = true;
        }
      }

      // Overtime flag
      if (overtimeMinutes != null && overtimeMinutes.inMinutes > 30) {
        flags.add(AttendanceFlag.overtime);
        if (overtimeMinutes.inMinutes > 120) { // More than 2 hours overtime
          requiresJustification = true;
        }
      }

      // Early clock out flag
      if (attendance.clockOut != null && attendance.clockOut!.isBefore(expectedClockOut)) {
        final earlyLeave = expectedClockOut.difference(attendance.clockOut!);
        if (earlyLeave.inMinutes > 30) {
          flags.add(AttendanceFlag.earlyClockOut);
          requiresJustification = true;
        }
      }

      // Invalid duration flags
      if (actualDuration != null) {
        if (actualDuration.inHours > 16) { // More than 16 hours work
          flags.add(AttendanceFlag.invalidDuration);
          flags.add(AttendanceFlag.suspicious);
          requiresJustification = true;
        } else if (actualDuration.inMinutes < 60) { // Less than 1 hour work
          flags.add(AttendanceFlag.invalidDuration);
          requiresJustification = true;
        }
      }

      // Long break detection (if there's a significant gap in expected vs actual time)
      if (actualDuration != null && scheduledDuration.inMinutes > 0) {
        final expectedWorkTime = scheduledDuration.inMinutes;
        final actualWorkTime = actualDuration.inMinutes;
        final difference = (actualWorkTime - expectedWorkTime).abs();
        
        if (difference > 120 && !flags.contains(AttendanceFlag.overtime)) { // 2+ hour difference
          flags.add(AttendanceFlag.longBreak);
        }
      }

      // Create audit log entry
      List<String> auditLog = List.from(attendance.auditLog);
      auditLog.add(
        '${DateTime.now().toIso8601String()}: Analytics calculated - '
        'Flags: ${flags.map((f) => f.toString().split('.').last).join(', ')}'
      );

      return attendance.copyWith(
        shiftId: shift.id,
        teamId: user?.teamId,
        scheduledDuration: scheduledDuration,
        actualDuration: actualDuration,
        latenessMinutes: latenessMinutes,
        overtimeMinutes: overtimeMinutes,
        expectedClockIn: expectedClockIn,
        expectedClockOut: expectedClockOut,
        flags: flags,
        requiresJustification: requiresJustification,
        updatedAt: DateTime.now(),
        lastModifiedBy: 'system',
        auditLog: auditLog,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating attendance analytics: $e');
      }
      return attendance;
    }
  }

  /// Parse shift time (e.g., "08:30") with attendance date
  DateTime _parseShiftDateTime(DateTime date, String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Get weekly analytics for a worker
  Future<Map<String, dynamic>> getWeeklyAnalytics({
    required String workerId,
    DateTime? startDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(Duration(days: 7));
      final end = start.add(Duration(days: 7));
      
      final startDateStr = DateFormat('yyyy-MM-dd').format(start);
      final endDateStr = DateFormat('yyyy-MM-dd').format(end);

      final snapshot = await _firestore
          .collection('attendance')
          .doc(workerId)
          .collection('records')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .get();

      final records = snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data()))
          .toList();

      return _calculateAnalyticsSummary(records);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting weekly analytics for $workerId: $e');
      }
      return {};
    }
  }

  /// Get team analytics for managers
  Future<Map<String, dynamic>> getTeamAnalytics({
    required String teamId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(Duration(days: 7));
      final end = endDate ?? DateTime.now();
      
      final startDateStr = DateFormat('yyyy-MM-dd').format(start);
      final endDateStr = DateFormat('yyyy-MM-dd').format(end);

      // Get all team members
      final teamSnapshot = await _firestore
          .collection('teams')
          .doc(teamId)
          .get();
      
      if (!teamSnapshot.exists) {
        return {};
      }

      final teamData = teamSnapshot.data()!;
      final memberIds = List<String>.from(teamData['memberIds'] ?? []);

      List<AttendanceModel> allRecords = [];

      // Collect attendance records for all team members
      for (String memberId in memberIds) {
        final memberSnapshot = await _firestore
            .collection('attendance')
            .doc(memberId)
            .collection('records')
            .where('date', isGreaterThanOrEqualTo: startDateStr)
            .where('date', isLessThanOrEqualTo: endDateStr)
            .get();

        final memberRecords = memberSnapshot.docs
            .map((doc) => AttendanceModel.fromMap(doc.data()))
            .toList();
        
        allRecords.addAll(memberRecords);
      }

      final analytics = _calculateAnalyticsSummary(allRecords);
      analytics['teamId'] = teamId;
      analytics['memberCount'] = memberIds.length;
      analytics['recordsAnalyzed'] = allRecords.length;

      return analytics;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting team analytics for $teamId: $e');
      }
      return {};
    }
  }

  /// Calculate analytics summary from a list of attendance records
  Map<String, dynamic> _calculateAnalyticsSummary(List<AttendanceModel> records) {
    if (records.isEmpty) {
      return {
        'totalRecords': 0,
        'totalWorkHours': 0.0,
        'totalOvertimeHours': 0.0,
        'lateCount': 0,
        'averageWorkHours': 0.0,
        'flaggedRecords': 0,
        'justificationsPending': 0,
        'perfectAttendanceCount': 0,
      };
    }

    double totalWorkHours = 0;
    double totalOvertimeHours = 0;
    int lateCount = 0;
    int flaggedRecords = 0;
    int justificationsPending = 0;
    int perfectAttendanceCount = 0;

    for (final record in records) {
      // Calculate work hours
      if (record.actualDuration != null) {
        totalWorkHours += record.actualDuration!.inMinutes / 60.0;
      }

      // Calculate overtime
      if (record.overtimeMinutes != null) {
        totalOvertimeHours += record.overtimeMinutes!.inMinutes / 60.0;
      }

      // Count late arrivals
      if (record.isLate) {
        lateCount++;
      }

      // Count flagged records
      if (record.flags.isNotEmpty) {
        flaggedRecords++;
      }

      // Count pending justifications
      if (record.requiresJustification && 
          (record.justification == null || 
           record.justification!.status == JustificationStatus.pending)) {
        justificationsPending++;
      }

      // Count perfect attendance (on time, no flags, complete)
      if (!record.isLate && 
          record.flags.isEmpty && 
          record.isComplete) {
        perfectAttendanceCount++;
      }
    }

    return {
      'totalRecords': records.length,
      'totalWorkHours': totalWorkHours,
      'totalOvertimeHours': totalOvertimeHours,
      'lateCount': lateCount,
      'averageWorkHours': records.length > 0 ? totalWorkHours / records.length : 0.0,
      'flaggedRecords': flaggedRecords,
      'justificationsPending': justificationsPending,
      'perfectAttendanceCount': perfectAttendanceCount,
      'attendanceRate': records.length > 0 ? 
          (perfectAttendanceCount / records.length * 100).round() : 0,
      'punctualityRate': records.length > 0 ? 
          ((records.length - lateCount) / records.length * 100).round() : 0,
    };
  }

  /// Get flagged records that need manager attention
  Future<List<AttendanceModel>> getFlaggedRecords({
    String? teamId,
    DateTime? startDate,
    DateTime? endDate,
    List<AttendanceFlag>? filterFlags,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(Duration(days: 30));
      final end = endDate ?? DateTime.now();
      
      final startDateStr = DateFormat('yyyy-MM-dd').format(start);
      final endDateStr = DateFormat('yyyy-MM-dd').format(end);

      List<AttendanceModel> flaggedRecords = [];

      if (teamId != null) {
        // Get team members first
        final teamSnapshot = await _firestore
            .collection('teams')
            .doc(teamId)
            .get();
        
        if (!teamSnapshot.exists) return [];

        final teamData = teamSnapshot.data()!;
        final memberIds = List<String>.from(teamData['memberIds'] ?? []);

        // Query each member's attendance
        for (String memberId in memberIds) {
          final memberRecords = await _getWorkerFlaggedRecords(
            memberId, startDateStr, endDateStr, filterFlags);
          flaggedRecords.addAll(memberRecords);
        }
      } else {
        // Query all attendance records (for company-wide view)
        final snapshot = await _firestore
            .collectionGroup('records')
            .where('date', isGreaterThanOrEqualTo: startDateStr)
            .where('date', isLessThanOrEqualTo: endDateStr)
            .where('requiresJustification', isEqualTo: true)
            .get();

        for (final doc in snapshot.docs) {
          final record = AttendanceModel.fromMap(doc.data());
          if (_matchesFilterFlags(record, filterFlags)) {
            flaggedRecords.add(record);
          }
        }
      }

      // Sort by most recent first
      flaggedRecords.sort((a, b) => b.clockIn.compareTo(a.clockIn));

      return flaggedRecords;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting flagged records: $e');
      }
      return [];
    }
  }

  /// Get flagged records for a specific worker
  Future<List<AttendanceModel>> _getWorkerFlaggedRecords(
    String workerId,
    String startDate,
    String endDate,
    List<AttendanceFlag>? filterFlags,
  ) async {
    final snapshot = await _firestore
        .collection('attendance')
        .doc(workerId)
        .collection('records')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .where('requiresJustification', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.data()))
        .where((record) => _matchesFilterFlags(record, filterFlags))
        .toList();
  }

  /// Check if record matches filter flags
  bool _matchesFilterFlags(AttendanceModel record, List<AttendanceFlag>? filterFlags) {
    if (filterFlags == null || filterFlags.isEmpty) return true;
    return record.flags.any((flag) => filterFlags.contains(flag));
  }

  /// Submit justification for attendance record
  Future<void> submitJustification({
    required String workerId,
    required String recordId,
    required String reason,
    required String submittedByUserId,
    required String submittedByUserName,
  }) async {
    try {
      final justification = AttendanceJustification(
        reason: reason,
        status: JustificationStatus.pending,
        submittedAt: DateTime.now(),
      );

      final auditEntry = '${DateTime.now().toIso8601String()}: '
          'Justification submitted by $submittedByUserName: $reason';

      await _firestore
          .collection('attendance')
          .doc(workerId)
          .collection('records')
          .doc(recordId)
          .update({
        'justification': justification.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
        'lastModifiedBy': submittedByUserId,
        'auditLog': FieldValue.arrayUnion([auditEntry]),
      });

      if (kDebugMode) {
        print('Justification submitted for record $recordId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting justification: $e');
      }
      rethrow;
    }
  }

  /// Approve or reject justification (manager action)
  Future<void> processJustification({
    required String workerId,
    required String recordId,
    required bool approved,
    required String managerId,
    required String managerName,
    String? rejectionReason,
  }) async {
    try {
      final status = approved ? JustificationStatus.approved : JustificationStatus.rejected;
      final now = DateTime.now();      final updateData = <String, dynamic>{
        'justification.status': status.toString().split('.').last,
        'justification.approvedByManagerId': managerId,
        'justification.approvedByManagerName': managerName,
        'justification.approvedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'lastModifiedBy': managerId,
      };

      if (!approved && rejectionReason != null) {
        updateData['justification.rejectionReason'] = rejectionReason;
      }

      final auditEntry = '${now.toIso8601String()}: '
          'Justification ${approved ? 'approved' : 'rejected'} by $managerName'
          '${rejectionReason != null ? ' - Reason: $rejectionReason' : ''}';

      updateData['auditLog'] = FieldValue.arrayUnion([auditEntry]);

      await _firestore
          .collection('attendance')
          .doc(workerId)
          .collection('records')
          .doc(recordId)
          .update(updateData);

      if (kDebugMode) {
        print('Justification ${approved ? 'approved' : 'rejected'} for record $recordId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing justification: $e');
      }
      rethrow;
    }
  }

  /// Add comment to attendance record
  Future<void> addComment({
    required String workerId,
    required String recordId,
    required String comment,
    required String authorId,
    required String authorName,
    required String authorRole,
  }) async {
    try {
      final attendanceComment = AttendanceComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        authorId: authorId,
        authorName: authorName,
        authorRole: authorRole,
        comment: comment,
        timestamp: DateTime.now(),
      );

      final auditEntry = '${DateTime.now().toIso8601String()}: '
          'Comment added by $authorName ($authorRole): $comment';

      await _firestore
          .collection('attendance')
          .doc(workerId)
          .collection('records')
          .doc(recordId)
          .update({
        'justification.comments': FieldValue.arrayUnion([attendanceComment.toMap()]),
        'updatedAt': DateTime.now().toIso8601String(),
        'lastModifiedBy': authorId,
        'auditLog': FieldValue.arrayUnion([auditEntry]),
      });

      if (kDebugMode) {
        print('Comment added to record $recordId by $authorName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding comment: $e');
      }
      rethrow;
    }
  }
}
