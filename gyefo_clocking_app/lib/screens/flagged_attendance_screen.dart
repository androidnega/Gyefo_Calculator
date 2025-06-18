import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/services/attendance_analytics_service.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';
import 'package:intl/intl.dart';

class FlaggedAttendanceScreen extends StatefulWidget {
  final String? teamId;

  const FlaggedAttendanceScreen({super.key, this.teamId});

  @override
  State<FlaggedAttendanceScreen> createState() =>
      _FlaggedAttendanceScreenState();
}

class _FlaggedAttendanceScreenState extends State<FlaggedAttendanceScreen> {
  final AttendanceAnalyticsService _analyticsService =
      AttendanceAnalyticsService();

  List<AttendanceModel> _flaggedRecords = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<AttendanceFlag> _selectedFlags = [];
  String _filterStatus = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _loadFlaggedRecords();
  }

  Future<void> _loadFlaggedRecords() async {
    setState(() => _isLoading = true);

    try {
      final records = await _analyticsService.getFlaggedRecords(
        teamId: widget.teamId,
        startDate: _startDate,
        endDate: _endDate,
        filterFlags: _selectedFlags.isEmpty ? null : _selectedFlags,
      );

      // Apply status filter
      List<AttendanceModel> filteredRecords = records;
      if (_filterStatus != 'all') {
        filteredRecords =
            records.where((record) {
              if (_filterStatus == 'pending') {
                return record.justification == null ||
                    record.justification!.status == JustificationStatus.pending;
              } else if (_filterStatus == 'approved') {
                return record.justification?.status ==
                    JustificationStatus.approved;
              } else if (_filterStatus == 'rejected') {
                return record.justification?.status ==
                    JustificationStatus.rejected;
              }
              return true;
            }).toList();
      }

      setState(() {
        _flaggedRecords = filteredRecords;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading flagged records: $e')),
        );
      }
    }
  }

  Future<void> _showJustificationDialog(AttendanceModel record) async {
    String? workerName;
    try {
      final userData = await FirestoreService.getUserData(record.workerId);
      if (userData != null) {
        final user = UserModel.fromMap(userData, record.workerId);
        workerName = user.name;
      }
    } catch (e) {
      workerName = 'Unknown Worker';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => JustificationDialog(
            record: record,
            workerName: workerName ?? 'Unknown Worker',
            onUpdate: () => _loadFlaggedRecords(),
          ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadFlaggedRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flagged Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlaggedRecords,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text('All (${_flaggedRecords.length})'),
                  selected: _filterStatus == 'all',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'all');
                    _loadFlaggedRecords();
                  },
                ),
                FilterChip(
                  label: Text('Pending'),
                  selected: _filterStatus == 'pending',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'pending');
                    _loadFlaggedRecords();
                  },
                ),
                FilterChip(
                  label: Text('Approved'),
                  selected: _filterStatus == 'approved',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'approved');
                    _loadFlaggedRecords();
                  },
                ),
                FilterChip(
                  label: Text('Rejected'),
                  selected: _filterStatus == 'rejected',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'rejected');
                    _loadFlaggedRecords();
                  },
                ),
              ],
            ),
          ),
          // Records list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _flaggedRecords.isEmpty
                    ? const Center(
                      child: Text(
                        'No flagged records found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _flaggedRecords.length,
                      itemBuilder: (context, index) {
                        final record = _flaggedRecords[index];
                        return FlaggedAttendanceCard(
                          record: record,
                          onTap: () => _showJustificationDialog(record),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => FilterDialog(
            selectedFlags: _selectedFlags,
            onApply: (flags) {
              setState(() => _selectedFlags = flags);
              _loadFlaggedRecords();
            },
          ),
    );
  }
}

class FlaggedAttendanceCard extends StatelessWidget {
  final AttendanceModel record;
  final VoidCallback onTap;

  const FlaggedAttendanceCard({
    super.key,
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: FutureBuilder<String>(
          future: _getWorkerName(),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? record.workerId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy').format(record.clockIn),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children:
                  record.flags
                      .map(
                        (flag) => Chip(
                          label: Text(
                            flag.toString().split('.').last,
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: _getFlagColor(flag),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 4),
            Text(
              'Clock-in: ${DateFormat('HH:mm').format(record.clockIn)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (record.clockOut != null)
              Text(
                'Clock-out: ${DateFormat('HH:mm').format(record.clockOut!)}',
                style: const TextStyle(fontSize: 12),
              ),
            if (record.isLate)
              Text(
                'Lateness: ${record.latenessFormatted}',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            if (record.hasOvertime)
              Text(
                'Overtime: ${record.overtimeFormatted}',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              record.justification != null
                  ? _getJustificationIcon(record.justification!.status)
                  : Icons.warning,
              color:
                  record.justification != null
                      ? _getJustificationColor(record.justification!.status)
                      : Colors.orange,
            ),
            Text(
              record.justification?.status.toString().split('.').last ??
                  'Pending',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getWorkerName() async {
    try {
      final userData = await FirestoreService.getUserData(record.workerId);
      if (userData != null) {
        final user = UserModel.fromMap(userData, record.workerId);
        return user.name;
      }
    } catch (e) {
      // Handle error silently
    }
    return record.workerId;
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
      case AttendanceFlag.nonWorkingDay:
        return Colors.grey.withValues(alpha: 0.3);
      case AttendanceFlag.unauthorizedOvertime:
        return Colors.deepOrange.withValues(alpha: 0.3);
    }
  }

  IconData _getJustificationIcon(JustificationStatus status) {
    switch (status) {
      case JustificationStatus.pending:
        return Icons.hourglass_empty;
      case JustificationStatus.approved:
        return Icons.check_circle;
      case JustificationStatus.rejected:
        return Icons.cancel;
    }
  }

  Color _getJustificationColor(JustificationStatus status) {
    switch (status) {
      case JustificationStatus.pending:
        return Colors.orange;
      case JustificationStatus.approved:
        return Colors.green;
      case JustificationStatus.rejected:
        return Colors.red;
    }
  }
}

class FilterDialog extends StatefulWidget {
  final List<AttendanceFlag> selectedFlags;
  final Function(List<AttendanceFlag>) onApply;

  const FilterDialog({
    super.key,
    required this.selectedFlags,
    required this.onApply,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late List<AttendanceFlag> _tempSelectedFlags;

  @override
  void initState() {
    super.initState();
    _tempSelectedFlags = List.from(widget.selectedFlags);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Flags'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              AttendanceFlag.values.map((flag) {
                return CheckboxListTile(
                  title: Text(flag.toString().split('.').last),
                  value: _tempSelectedFlags.contains(flag),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _tempSelectedFlags.add(flag);
                      } else {
                        _tempSelectedFlags.remove(flag);
                      }
                    });
                  },
                );
              }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            setState(() => _tempSelectedFlags.clear());
          },
          child: const Text('Clear All'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_tempSelectedFlags);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class JustificationDialog extends StatefulWidget {
  final AttendanceModel record;
  final String workerName;
  final VoidCallback onUpdate;

  const JustificationDialog({
    super.key,
    required this.record,
    required this.workerName,
    required this.onUpdate,
  });

  @override
  State<JustificationDialog> createState() => _JustificationDialogState();
}

class _JustificationDialogState extends State<JustificationDialog> {
  final AttendanceAnalyticsService _analyticsService =
      AttendanceAnalyticsService();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _rejectionController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    return AlertDialog(
      title: Text('Attendance Details - ${widget.workerName}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Basic info
            _buildInfoRow(
              'Date',
              DateFormat('MMM dd, yyyy').format(record.clockIn),
            ),
            _buildInfoRow(
              'Clock-in',
              DateFormat('HH:mm').format(record.clockIn),
            ),
            if (record.clockOut != null)
              _buildInfoRow(
                'Clock-out',
                DateFormat('HH:mm').format(record.clockOut!),
              ),
            _buildInfoRow('Work Duration', record.workDurationFormatted),
            if (record.isLate)
              _buildInfoRow('Lateness', record.latenessFormatted),
            if (record.hasOvertime)
              _buildInfoRow('Overtime', record.overtimeFormatted),

            const SizedBox(height: 16),

            // Flags
            const Text('Flags:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children:
                  record.flags
                      .map(
                        (flag) => Chip(
                          label: Text(flag.toString().split('.').last),
                          backgroundColor: Colors.orange.withValues(alpha: 0.3),
                        ),
                      )
                      .toList(),
            ),

            const SizedBox(height: 16),

            // Justification section
            if (record.justification != null) ...[
              const Text(
                'Justification:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason: ${record.justification!.reason}'),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${record.justification!.status.toString().split('.').last}',
                      style: TextStyle(
                        color:
                            record.justification!.status ==
                                    JustificationStatus.approved
                                ? Colors.green
                                : record.justification!.status ==
                                    JustificationStatus.rejected
                                ? Colors.red
                                : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (record.justification!.approvedByManagerName != null)
                      Text(
                        'Processed by: ${record.justification!.approvedByManagerName}',
                      ),
                    if (record.justification!.rejectionReason != null)
                      Text(
                        'Rejection reason: ${record.justification!.rejectionReason}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Comments section
            if (record.justification?.comments.isNotEmpty == true) ...[
              const Text(
                'Comments:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...record.justification!.comments.map(
                (comment) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.authorName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${comment.authorRole})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat(
                              'MMM dd, HH:mm',
                            ).format(comment.timestamp),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment.comment),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Add comment section
            const Text(
              'Add Comment:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Enter your comment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (_commentController.text.isNotEmpty)
          TextButton(
            onPressed: _isLoading ? null : _addComment,
            child: const Text('Add Comment'),
          ),
        if (record.justification?.status == JustificationStatus.pending) ...[
          TextButton(
            onPressed: _isLoading ? null : _showRejectDialog,
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _processJustification(true),
            child: const Text('Approve'),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final userData = await FirestoreService.getUserData(currentUser.uid);
      if (userData == null) throw Exception('User data not found');

      final user = UserModel.fromMap(userData, currentUser.uid);

      await _analyticsService.addComment(
        workerId: widget.record.workerId,
        recordId: '', // We need to implement a way to get the record ID
        comment: _commentController.text.trim(),
        authorId: currentUser.uid,
        authorName: user.name,
        authorRole: user.role,
      );

      _commentController.clear();
      widget.onUpdate();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding comment: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reject Justification'),
            content: TextField(
              controller: _rejectionController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _processJustification(false);
                },
                child: const Text('Reject'),
              ),
            ],
          ),
    );
  }

  Future<void> _processJustification(bool approved) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final userData = await FirestoreService.getUserData(currentUser.uid);
      if (userData == null) throw Exception('User data not found');

      final user = UserModel.fromMap(userData, currentUser.uid);

      await _analyticsService.processJustification(
        workerId: widget.record.workerId,
        recordId: '', // We need to implement a way to get the record ID
        approved: approved,
        managerId: currentUser.uid,
        managerName: user.name,
        rejectionReason: approved ? null : _rejectionController.text.trim(),
      );

      widget.onUpdate();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Justification ${approved ? 'approved' : 'rejected'} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing justification: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _rejectionController.dispose();
    super.dispose();
  }
}
