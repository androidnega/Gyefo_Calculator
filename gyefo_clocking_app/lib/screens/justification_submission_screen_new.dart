import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/services/attendance_analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class JustificationSubmissionScreen extends StatefulWidget {
  final AttendanceModel record;
  final String recordId;

  const JustificationSubmissionScreen({
    super.key,
    required this.record,
    required this.recordId,
  });

  @override
  State<JustificationSubmissionScreen> createState() =>
      _JustificationSubmissionScreenState();
}

class _JustificationSubmissionScreenState
    extends State<JustificationSubmissionScreen> {
  final AttendanceAnalyticsService _analyticsService =
      AttendanceAnalyticsService();
  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;

  final List<String> _predefinedReasons = [
    'Traffic jam on the way to work',
    'Public transport delay',
    'Family emergency',
    'Medical appointment',
    'Car breakdown',
    'Power outage at home',
    'Internet connectivity issues',
    'Childcare issues',
    'Other (please specify)',
  ];

  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit Justification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attendance details card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Date',
                      DateFormat('MMM dd, yyyy').format(record.clockIn),
                    ),
                    _buildDetailRow(
                      'Clock-in',
                      DateFormat('HH:mm').format(record.clockIn),
                    ),
                    if (record.clockOut != null)
                      _buildDetailRow(
                        'Clock-out',
                        DateFormat('HH:mm').format(record.clockOut!),
                      ),
                    if (record.actualDuration != null)
                      _buildDetailRow(
                        'Work Duration',
                        record.workDurationFormatted,
                      ),
                    if (record.isLate)
                      _buildDetailRow('Lateness', record.latenessFormatted),
                    if (record.hasOvertime)
                      _buildDetailRow('Overtime', record.overtimeFormatted),

                    const SizedBox(height: 12),
                    const Text(
                      'Issues Detected:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          record.flags
                              .map(
                                (flag) => Chip(
                                  label: Text(
                                    flag.toString().split('.').last,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: _getFlagColor(flag),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Justification form
            const Text(
              'Explain the reason for this attendance issue:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Predefined reasons
            const Text(
              'Select a reason:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._predefinedReasons.map(
              (reason) => RadioListTile<String>(
                title: Text(reason),
                value: reason,
                groupValue: _selectedReason,
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                    if (value != 'Other (please specify)') {
                      _reasonController.text = value!;
                    } else {
                      _reasonController.clear();
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),

            const SizedBox(height: 16),

            // Custom reason text field
            if (_selectedReason == 'Other (please specify)' ||
                _selectedReason == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional details:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      hintText: 'Please provide a detailed explanation...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    onChanged: (value) {
                      setState(() {}); // Trigger rebuild for button state
                    },
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading || _reasonController.text.trim().isEmpty
                        ? null
                        : _submitJustification,
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Submit Justification'),
              ),
            ),

            const SizedBox(height: 16),

            // Info card
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your justification will be reviewed by your manager. '
                            'Please provide accurate and honest information.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getFlagColor(AttendanceFlag flag) {
    switch (flag) {
      case AttendanceFlag.late:
        return Colors.orange.withValues(alpha: 0.3);
      case AttendanceFlag.overtime:
        return Colors.blue.withValues(alpha: 0.3);
      case AttendanceFlag.outOfZone:
        return Colors.red.withValues(alpha: 0.3);
      case AttendanceFlag.suspicious:
        return Colors.purple.withValues(alpha: 0.3);
      case AttendanceFlag.earlyClockOut:
        return Colors.yellow.withValues(alpha: 0.3);
      case AttendanceFlag.invalidDuration:
        return Colors.pink.withValues(alpha: 0.3);
      case AttendanceFlag.longBreak:
        return Colors.cyan.withValues(alpha: 0.3);
    }
  }

  Future<void> _submitJustification() async {
    if (_reasonController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Not authenticated');
      }

      await _analyticsService.submitJustification(
        workerId: widget.record.workerId,
        recordId: widget.recordId,
        reason: _reasonController.text.trim(),
        submittedByUserId: currentUser.uid,
        submittedByUserName: currentUser.displayName ?? 'Unknown User',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Justification submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting justification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
