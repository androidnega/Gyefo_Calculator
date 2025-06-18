import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/services/attendance_analytics_service.dart';
import 'package:gyefo_clocking_app/screens/justification_submission_screen_new.dart';
import 'package:intl/intl.dart';

class WorkerFlaggedRecordsScreen extends StatefulWidget {
  const WorkerFlaggedRecordsScreen({super.key});

  @override
  State<WorkerFlaggedRecordsScreen> createState() =>
      _WorkerFlaggedRecordsScreenState();
}

class _WorkerFlaggedRecordsScreenState
    extends State<WorkerFlaggedRecordsScreen> {
  final AttendanceAnalyticsService _analyticsService =
      AttendanceAnalyticsService();
  List<AttendanceModel> _flaggedRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlaggedRecords();
  }

  Future<void> _loadFlaggedRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await _analyticsService.getMyFlaggedRecords();
      setState(() {
        _flaggedRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading flagged records: $e')),
        );
      }
    }
  }

  void _submitJustification(AttendanceModel record, String recordId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => JustificationSubmissionScreen(
              record: record,
              recordId: recordId,
            ),
      ),
    ).then((_) => _loadFlaggedRecords());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Flagged Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlaggedRecords,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _flaggedRecords.isEmpty
              ? _buildEmptyState()
              : _buildFlaggedRecordsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Flagged Records',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'All your attendance records are in good standing.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildFlaggedRecordsList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These records need your attention. Please provide justifications where required.',
                  style: TextStyle(color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _flaggedRecords.length,
            itemBuilder: (context, index) {
              final record = _flaggedRecords[index];
              return _buildFlaggedRecordCard(record, index.toString());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlaggedRecordCard(AttendanceModel record, String recordId) {
    final clockInTime = DateFormat('HH:mm').format(record.clockIn);
    final clockOutTime =
        record.clockOut != null
            ? DateFormat('HH:mm').format(record.clockOut!)
            : 'Not clocked out';
    final date = DateFormat('MMM dd, yyyy').format(record.clockIn);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$clockInTime - $clockOutTime',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FLAGGED',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (record.flags.isNotEmpty) ...[
              const Text(
                'Issues:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(height: 4),
              ...record.flags.map(
                (flag) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getFlagDescription(flag),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (record.justification != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Justification Submitted:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.justification!.reason,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _submitJustification(record, recordId),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Submit Justification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFlagDescription(AttendanceFlag flag) {
    switch (flag) {
      case AttendanceFlag.late:
        return 'Late clock-in';
      case AttendanceFlag.earlyClockOut:
        return 'Early clock-out';
      case AttendanceFlag.outOfZone:
        return 'Clocked in/out outside work zone';
      case AttendanceFlag.longBreak:
        return 'Extended break time';
      case AttendanceFlag.overtime:
        return 'Overtime work detected';
      case AttendanceFlag.invalidDuration:
        return 'Invalid work duration';
      case AttendanceFlag.suspicious:
        return 'Suspicious activity detected';
      case AttendanceFlag.nonWorkingDay:
        return 'Clocked in on non-working day';
      case AttendanceFlag.unauthorizedOvertime:
        return 'Unauthorized overtime';
    }
  }
}
