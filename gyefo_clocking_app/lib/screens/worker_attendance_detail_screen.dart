import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/services/export_service.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:intl/intl.dart';

class WorkerAttendanceDetailScreen extends StatefulWidget {
  final String workerId;
  const WorkerAttendanceDetailScreen({super.key, required this.workerId});

  @override
  State<WorkerAttendanceDetailScreen> createState() =>
      _WorkerAttendanceDetailScreenState();
}

class _WorkerAttendanceDetailScreenState
    extends State<WorkerAttendanceDetailScreen> {
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isExporting = false;
  UserModel? _workerInfo;
  String _filterType = 'all'; // 'all', 'single', 'range', 'week', 'month'

  @override
  void initState() {
    super.initState();
    _loadWorkerInfo();
  }

  Future<void> _loadWorkerInfo() async {
    try {
      final worker = await ExportService.getWorkerInfo(widget.workerId);
      if (mounted) {
        setState(() {
          _workerInfo = worker;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading worker info: $e');
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _filterType = 'single';
        _startDate = null;
        _endDate = null;
      });
    }
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _filterType = 'range';
        _selectedDate = null;
        // If end date is before start date, clear it
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _filterType = 'range';
        _selectedDate = null;
      });
    }
  }

  void _setQuickFilter(String filterType) {
    setState(() {
      _filterType = filterType;
      _selectedDate = null;
      _startDate = null;
      _endDate = null;

      final now = DateTime.now();
      switch (filterType) {
        case 'week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = _startDate!.add(const Duration(days: 6));
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'last7':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case 'last30':
          _startDate = now.subtract(const Duration(days: 30));
          _endDate = now;
          break;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _filterType = 'all';
      _selectedDate = null;
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _exportToCSV(List<AttendanceModel> records) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final file = await ExportService.exportWorkerAttendanceToCSV(
        widget.workerId,
        records: records,
        workerInfo: _workerInfo,
      );
      if (mounted) {
        if (file != null) {
          // Show success message with options
          _showExportSuccessDialog(file);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportToPDF(List<AttendanceModel> records) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final file = await ExportService.exportWorkerAttendanceToPDF(
        widget.workerId,
        records: records,
        workerInfo: _workerInfo,
      );
      if (mounted) {
        if (file != null) {
          // Show success message with options
          _showPDFExportSuccessDialog(file);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _previewPDF(List<AttendanceModel> records) async {
    try {
      await ExportService.previewWorkerAttendancePDF(
        widget.workerId,
        records: records,
        workerInfo: _workerInfo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF preview error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportSuccessDialog(File file) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Export Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendance records exported to:'),
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
                  await ExportService.shareCSVFile(
                    file,
                    _workerInfo?.name ?? 'Worker',
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
    );
  }
  void _showPDFExportSuccessDialog(File file) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('PDF Export Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendance records exported to PDF:'),
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
                  await ExportService.sharePDFFile(
                    file,
                    _workerInfo?.name ?? 'Worker',
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
    );
  }

  /// Helper method to create the filtered attendance query
  Query _buildAttendanceQuery() {
    Query attendanceQuery = FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.workerId)
        .collection('records');

    // Apply filters based on filter type
    if (_filterType == 'single' && _selectedDate != null) {
      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      attendanceQuery = attendanceQuery
          .where('date', isEqualTo: dateString)
          .orderBy('clockIn', descending: true);
    } else if (_filterType == 'range' &&
        _startDate != null &&
        _endDate != null) {
      final startDateString = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endDateString = DateFormat('yyyy-MM-dd').format(_endDate!);
      attendanceQuery = attendanceQuery
          .where('date', isGreaterThanOrEqualTo: startDateString)
          .where('date', isLessThanOrEqualTo: endDateString)
          .orderBy('date', descending: true)
          .orderBy('clockIn', descending: true);
    } else if (_filterType == 'week' ||
        _filterType == 'month' ||
        _filterType == 'last7' ||
        _filterType == 'last30') {
      if (_startDate != null && _endDate != null) {
        final startDateString = DateFormat('yyyy-MM-dd').format(_startDate!);
        final endDateString = DateFormat('yyyy-MM-dd').format(_endDate!);
        attendanceQuery = attendanceQuery
            .where('date', isGreaterThanOrEqualTo: startDateString)
            .where('date', isLessThanOrEqualTo: endDateString)
            .orderBy('date', descending: true)
            .orderBy('clockIn', descending: true);
      }
    } else {
      // All records - no date filter
      attendanceQuery = attendanceQuery.orderBy('clockIn', descending: true);
    }

    return attendanceQuery;
  }
  @override
  Widget build(BuildContext context) {
    final attendanceQuery = _buildAttendanceQuery();

    return Scaffold(
      appBar: AppBar(
        title: Text(_workerInfo?.name ?? 'Worker Attendance Details'),
        elevation: 0,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter options',
            onSelected: (value) {
              switch (value) {
                case 'single':
                  _pickDate(context);
                  break;
                case 'range_start':
                  _pickStartDate(context);
                  break;
                case 'range_end':
                  _pickEndDate(context);
                  break;
                case 'week':
                  _setQuickFilter('week');
                  break;
                case 'month':
                  _setQuickFilter('month');
                  break;
                case 'last7':
                  _setQuickFilter('last7');
                  break;
                case 'last30':
                  _setQuickFilter('last30');
                  break;
                case 'all':
                  _clearFilters();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'single',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today),
                        SizedBox(width: 8),
                        Text('Single Date'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'range_start',
                    child: Row(
                      children: [
                        Icon(Icons.date_range),
                        SizedBox(width: 8),
                        Text('Start Date'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'range_end',
                    child: Row(
                      children: [
                        Icon(Icons.date_range),
                        SizedBox(width: 8),
                        Text('End Date'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'week',
                    child: Row(
                      children: [
                        Icon(Icons.view_week),
                        SizedBox(width: 8),
                        Text('This Week'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'month',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month),
                        SizedBox(width: 8),
                        Text('This Month'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'last7',
                    child: Row(
                      children: [
                        Icon(Icons.history),
                        SizedBox(width: 8),
                        Text('Last 7 Days'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'last30',
                    child: Row(
                      children: [
                        Icon(Icons.history),
                        SizedBox(width: 8),
                        Text('Last 30 Days'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all),
                        SizedBox(width: 8),
                        Text('Clear Filters'),
                      ],
                    ),
                  ),
                ],
          ),          if (_filterType != 'all')
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilters,
              tooltip: 'Clear filters',
            ),          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Export options',
            enabled: !_isExporting,
            onSelected: (value) async {
              // Get current filtered records using the helper method
              final QuerySnapshot snapshot = await _buildAttendanceQuery().get();
              final records = snapshot.docs
                  .map((doc) => AttendanceModel.fromMap(
                        doc.data() as Map<String, dynamic>,
                      ))
                  .toList();
              
              if (value == 'csv') {
                await _exportToCSV(records);
              } else if (value == 'pdf') {
                await _exportToPDF(records);
              } else if (value == 'preview') {
                await _previewPDF(records);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.file_download),
                    SizedBox(width: 8),
                    Text('Export to CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Export to PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.preview),
                    SizedBox(width: 8),
                    Text('Preview PDF'),
                  ],
                ),
              ),            ],
          ),          // IconButton(
          //   icon: const Icon(Icons.calendar_month),
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => ManagerCalendarScreen(workerId: widget.workerId),
          //       ),
          //     );
          //   },
          //   tooltip: 'Calendar View',
          // ),
        ],
      ),body: Column(
        children: [
          // Date filter section
          if (_filterType != 'all')
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade100, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getFilterIcon(),
                    size: 20,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getFilterDescription(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),

          // Records list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: attendanceQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade700),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedDate != null
                              ? 'No records found for selected date'
                              : 'No attendance records found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedDate != null)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Show all records'),
                          ),
                      ],
                    ),
                  );
                }

                final records = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: records.length,
                  separatorBuilder:
                      (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final recordData =
                        records[index].data() as Map<String, dynamic>;
                    final record = AttendanceModel.fromMap(recordData);

                    final clockInTime = DateFormat(
                      'HH:mm:ss',
                    ).format(record.clockIn);
                    final clockOutTime =
                        record.clockOut != null
                            ? DateFormat('HH:mm:ss').format(record.clockOut!)
                            : 'Not yet clocked out';

                    String hoursWorked = 'Still working';
                    Color statusColor = Colors.orange;
                    if (record.clockOut != null) {
                      final duration = record.clockOut!.difference(
                        record.clockIn,
                      );
                      final hours = duration.inHours;
                      final minutes = duration.inMinutes % 60;
                      hoursWorked = '$hours hrs $minutes mins';
                      statusColor = Colors.green;
                    }

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 20,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  record.date,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    record.clockOut != null
                                        ? 'Completed'
                                        : 'In Progress',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: statusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildTimeInfo(
                                  icon: Icons.login,
                                  label: 'Clock In',
                                  time: clockInTime,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 24),
                                _buildTimeInfo(
                                  icon: Icons.logout,
                                  label: 'Clock Out',
                                  time: clockOutTime,
                                  color:
                                      record.clockOut != null
                                          ? Colors.red
                                          : Colors.grey,
                                ),
                              ],
                            ),
                            if (record.clockOut != null) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Time: ',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    hoursWorked,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFilterIcon() {
    switch (_filterType) {
      case 'single':
        return Icons.calendar_today;
      case 'range':
        return Icons.date_range;
      case 'week':
        return Icons.view_week;
      case 'month':
        return Icons.calendar_month;
      case 'last7':
      case 'last30':
        return Icons.history;
      default:
        return Icons.filter_list;
    }
  }

  String _getFilterDescription() {
    switch (_filterType) {
      case 'single':
        return 'Date: ${_selectedDate != null ? DateFormat('MMMM d, yyyy').format(_selectedDate!) : 'Not selected'}';
      case 'range':
        if (_startDate != null && _endDate != null) {
          return 'Range: ${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}';
        } else if (_startDate != null) {
          return 'From: ${DateFormat('MMMM d, yyyy').format(_startDate!)} (Select end date)';
        } else {
          return 'Date range: Select start and end dates';
        }
      case 'week':
        return 'This Week: ${_startDate != null ? DateFormat('MMM d').format(_startDate!) : ''} - ${_endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : ''}';
      case 'month':
        return 'This Month: ${_startDate != null ? DateFormat('MMMM yyyy').format(_startDate!) : ''}';
      case 'last7':
        return 'Last 7 Days';
      case 'last30':
        return 'Last 30 Days';
      default:
        return 'All Records';
    }
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
