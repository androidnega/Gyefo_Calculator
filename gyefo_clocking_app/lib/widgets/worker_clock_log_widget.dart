import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/utils/app_theme.dart';
import 'package:intl/intl.dart';

class WorkerClockLogWidget extends StatelessWidget {
  final String workerId;
  final int daysToShow;

  const WorkerClockLogWidget({
    super.key,
    required this.workerId,
    this.daysToShow = 7, // Show last 7 days by default
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'Clock-in/out Logs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  'Last $daysToShow days',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400, // Fixed height for scrollable logs
              child: StreamBuilder<QuerySnapshot>(
                stream: _getClockLogsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.errorRed,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error loading logs',
                            style: TextStyle(color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.history,
                            color: AppTheme.textLight,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No clock logs available',
                            style: TextStyle(color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {                      final doc = snapshot.data!.docs[index];
                      final attendance = AttendanceModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                      );
                      return _buildLogEntry(context, attendance);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getClockLogsStream() {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToShow));
    final cutoffDateString = DateFormat('yyyy-MM-dd').format(cutoffDate);

    return FirebaseFirestore.instance
        .collection('attendance')
        .doc(workerId)
        .collection('records')
        .where('date', isGreaterThanOrEqualTo: cutoffDateString)
        .orderBy('date', descending: true)
        .orderBy('clockIn', descending: true)
        .limit(50) // Limit to prevent excessive data
        .snapshots();
  }

  Widget _buildLogEntry(BuildContext context, AttendanceModel attendance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Row(
            children: [
              Text(
                _formatDate(attendance.clockIn),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              if (attendance.flags.isNotEmpty) _buildFlagsIndicator(attendance.flags),
            ],
          ),
          const SizedBox(height: 8),
          
          // Clock-in entry
          _buildClockEntry(
            context,
            'Clock In',
            attendance.clockIn,
            attendance.clockInLocation,
            Icons.login,
            AppColors.clockInGreen,
            _getClockInStatus(attendance),
          ),
          
          // Clock-out entry (if available)
          if (attendance.clockOut != null) ...[
            const SizedBox(height: 4),
            _buildClockEntry(
              context,
              'Clock Out',
              attendance.clockOut!,
              attendance.clockOutLocation,
              Icons.logout,
              AppColors.clockOutBlue,
              _getClockOutStatus(attendance),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.logout,
                  color: AppTheme.textLight,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Still clocked in',
                  style: TextStyle(
                    color: AppTheme.textLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
          
          // Total hours (if both clock-in and clock-out exist)
          if (attendance.clockOut != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.timer,
                  color: AppTheme.primaryGreen,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total: ${_calculateHours(attendance.clockIn, attendance.clockOut!)}',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClockEntry(
    BuildContext context,
    String label,
    DateTime time,
    AttendanceLocation? location,
    IconData icon,
    Color color,
    String? status,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$label: ${_formatTime(time)}',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (location != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      location.isWithinWorkZone ? Icons.location_on : Icons.location_off,
                      size: 12,
                      color: location.isWithinWorkZone ? AppColors.clockInGreen : AppColors.flaggedRed,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatLocation(location),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlagsIndicator(List<AttendanceFlag> flags) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: flags.map((flag) {
        Color flagColor;
        String flagText;
        
        switch (flag) {
          case AttendanceFlag.late:
            flagColor = Colors.orange;
            flagText = 'LATE';
            break;          case AttendanceFlag.earlyClockOut:
            flagColor = Colors.red;
            flagText = 'EARLY';
            break;
          case AttendanceFlag.nonWorkingDay:
            flagColor = Colors.purple;
            flagText = 'OFF-DAY';
            break;
          default:
            flagColor = AppTheme.textLight;
            flagText = flag.toString().split('.').last.toUpperCase();
        }
        
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: flagColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: flagColor, width: 1),
          ),
          child: Text(
            flagText,
            style: TextStyle(
              fontSize: 10,
              color: flagColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  String? _getClockInStatus(AttendanceModel attendance) {
    if (attendance.flags.contains(AttendanceFlag.late)) {
      return 'Late';
    }
    return 'On Time';
  }
  String? _getClockOutStatus(AttendanceModel attendance) {
    if (attendance.flags.contains(AttendanceFlag.earlyClockOut)) {
      return 'Early';
    }
    return 'On Time';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'late':
        return Colors.orange;
      case 'early':
        return Colors.red;
      case 'on time':
        return AppColors.clockInGreen;
      default:
        return AppTheme.textLight;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMM d').format(date);
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  String _formatLocation(AttendanceLocation location) {
    final withinZone = location.isWithinWorkZone ? 'Within work zone' : 'Outside work zone';
    final coords = '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    final distance = location.distanceFromWork != null 
        ? ' • ${location.distanceFromWork!.toStringAsFixed(0)}m from work'
        : '';
    
    return '$withinZone • $coords$distance';
  }

  String _calculateHours(DateTime clockIn, DateTime clockOut) {
    final duration = clockOut.difference(clockIn);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
