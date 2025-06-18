import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:gyefo_clocking_app/widgets/clock_button.dart';
import 'package:gyefo_clocking_app/widgets/worker_info_card.dart';
import 'package:gyefo_clocking_app/services/auth_service.dart';
import 'package:gyefo_clocking_app/services/attendance_service.dart';
import 'package:gyefo_clocking_app/services/export_service.dart';
import 'package:gyefo_clocking_app/services/offline_sync_service.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:gyefo_clocking_app/screens/worker_attendance_detail_screen.dart';
import 'package:gyefo_clocking_app/screens/notification_settings_screen.dart';
import 'package:gyefo_clocking_app/widgets/offline_sync_widgets.dart';
import 'package:intl/intl.dart';

class WorkerDashboard extends StatefulWidget {
  final OfflineSyncService? offlineSyncService;

  const WorkerDashboard({super.key, this.offlineSyncService});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final AttendanceService _attendanceService = AttendanceService();
  List<AttendanceModel> _recentAttendance = [];
  UserModel? _workerInfo;
  bool _isLoading = true;
  bool _hasActiveSession = false;
  Map<String, dynamic>? _todayRecord;
  Timer? _clockTimer;
  Duration _workingDuration = Duration.zero;
  DateTime? _clockInTime;
  @override
  void initState() {
    super.initState();
    _loadWorkerData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startLiveTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_hasActiveSession && _clockInTime != null) {
        setState(() {
          _workingDuration = DateTime.now().difference(_clockInTime!);
        });
      }
    });
  }

  void _stopLiveTimer() {
    _clockTimer?.cancel();
    setState(() {
      _workingDuration = Duration.zero;
    });
  }

  String _formatWorkingDuration() {
    if (_workingDuration == Duration.zero) return '';

    final hours = _workingDuration.inHours;
    final minutes = _workingDuration.inMinutes % 60;
    final seconds = _workingDuration.inSeconds % 60;

    if (hours > 0) {
      return ' (${hours}h ${minutes}m ${seconds}s)';
    } else if (minutes > 0) {
      return ' (${minutes}m ${seconds}s)';
    } else {
      return ' (${seconds}s)';
    }
  }

  Future<void> _loadWorkerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load worker info
      _workerInfo = await ExportService.getWorkerInfo(user.uid);

      // Check if worker has an active session today
      _hasActiveSession = await _attendanceService.hasClockedInToday(
        user.uid,
      ); // Get today's record
      _todayRecord = await _attendanceService.getTodayActiveRecord(user.uid);

      // Set up live timer if clocked in
      if (_hasActiveSession && _todayRecord != null) {
        _clockInTime = DateTime.parse(_todayRecord!['clockIn']);
        _startLiveTimer();
      } else {
        _stopLiveTimer();
      }

      // Load recent attendance (last 7 days)
      _recentAttendance = await _attendanceService.getWorkerAttendanceLastDays(
        workerId: user.uid,
        days: 7,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading worker data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadWorkerData();
  }

  Future<void> _exportMyAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get all attendance records for this worker
      final records = await _attendanceService.getWorkerAttendanceRecords(
        workerId: user.uid,
      );

      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No attendance records to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show export options dialog
      _showExportOptionsDialog(records);
    } catch (e) {
      AppLogger.error('Error preparing export: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportOptionsDialog(List<AttendanceModel> records) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Export Records'),
            content: const Text('Choose export format:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _exportToCSV(records);
                },
                icon: const Icon(Icons.file_download),
                label: const Text('Export CSV'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _exportToPDF(records);
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
            ],
          ),
    );
  }

  Future<void> _exportToCSV(List<AttendanceModel> records) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final file = await ExportService.exportWorkerAttendanceToCSV(
        user.uid,
        records: records,
        workerInfo: _workerInfo,
      );
      if (mounted) {
        if (file != null) {
          _showExportSuccessDialog(file, 'CSV');
        } else {
          // For web, file is null but export was successful
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV export successful! File has been shared.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('CSV export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF(List<AttendanceModel> records) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final file = await ExportService.exportWorkerAttendanceToPDF(
        user.uid,
        records: records,
        workerInfo: _workerInfo,
      );
      if (mounted) {
        if (file != null) {
          _showExportSuccessDialog(file, 'PDF');
        } else {
          // For web, file is null but export was successful
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF export successful! File has been shared.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('PDF export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportSuccessDialog(dynamic file, String format) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('$format Export Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your attendance records exported to $format:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    file.path,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (format == 'CSV') {
                    await ExportService.shareCSVFile(
                      file,
                      _workerInfo?.name ?? 'Worker',
                    );
                  } else {
                    await ExportService.sharePDFFile(
                      file,
                      _workerInfo?.name ?? 'Worker',
                    );
                  }
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
    );
  }

  void _viewFullAttendanceHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Navigate to the worker attendance detail screen to view their own records
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkerAttendanceDetailScreen(workerId: user.uid),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await AuthService().signOut();
      // Navigation will be handled automatically by the StreamBuilder in main.dart
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportMyAttendance,
            tooltip: 'Export Records',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationSettingsScreen(),
                  ),
                ),
            tooltip: 'Notification Settings',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _refreshData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Offline Sync Status
                      if (widget.offlineSyncService != null)
                        OfflineSyncStatusWidget(
                          syncService: widget.offlineSyncService!,
                        ),

                      // Worker Info Card
                      if (_workerInfo != null)
                        WorkerInfoCard(worker: _workerInfo!),
                      const SizedBox(height: 16),

                      // Welcome Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue.shade50,
                                    child: Text(
                                      (_workerInfo?.name ?? user?.email ?? 'W')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome, ${_workerInfo?.name ?? 'Worker'}!',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          user?.email ?? 'Unknown User',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Today: ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Today's Status Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _hasActiveSession
                                        ? Icons.access_time
                                        : Icons.schedule,
                                    color:
                                        _hasActiveSession
                                            ? Colors.green
                                            : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Today\'s Status',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      _hasActiveSession
                                          ? Colors.green.shade50
                                          : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        _hasActiveSession
                                            ? Colors.green.shade200
                                            : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _hasActiveSession
                                          ? Icons.work
                                          : Icons.work_off,
                                      color:
                                          _hasActiveSession
                                              ? Colors.green
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _hasActiveSession
                                            ? 'Currently clocked in - Working${_formatWorkingDuration()}'
                                            : 'Not clocked in',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color:
                                              _hasActiveSession
                                                  ? Colors.green.shade700
                                                  : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_todayRecord != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Clock in time: ${DateFormat('HH:mm:ss').format(DateTime.parse(_todayRecord!['clockIn']))}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Clock In/Out Section
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                'Time Tracking',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ClockButton(onClockStatusChanged: _refreshData),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Stats Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recent Activity',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatItem(
                                      icon: Icons.calendar_month,
                                      label: 'This Week',
                                      value:
                                          '${_recentAttendance.where((r) => _isThisWeek(r.clockIn)).length} days',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatItem(
                                      icon: Icons.access_time,
                                      label: 'Total Hours',
                                      value: '${_calculateTotalHours()} hrs',
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _viewFullAttendanceHistory,
                                  icon: const Icon(Icons.history),
                                  label: const Text('View Full History'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Actions Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _exportMyAttendance,
                                      icon: const Icon(
                                        Icons.download,
                                        size: 20,
                                      ),
                                      label: const Text('Export'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade600,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _viewFullAttendanceHistory,
                                      icon: const Icon(
                                        Icons.analytics,
                                        size: 20,
                                      ),
                                      label: const Text('Reports'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Instructions Card
                      Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'How to Use',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• Clock in when you start your work day',
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '• Clock out when you finish your work day',
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '• View your attendance history anytime',
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '• Export your records for personal use',
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '• Contact your manager if you have issues',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  double _calculateTotalHours() {
    double total = 0;
    for (final record in _recentAttendance) {
      if (record.clockOut != null) {
        final duration = record.clockOut!.difference(record.clockIn);
        total += duration.inMinutes / 60.0;
      }
    }
    return double.parse(total.toStringAsFixed(1));
  }
}
