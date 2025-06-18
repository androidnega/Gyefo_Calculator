import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/models/team_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/services/team_service.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class WorkerInfoCard extends StatefulWidget {
  final UserModel worker;

  const WorkerInfoCard({super.key, required this.worker});

  @override
  State<WorkerInfoCard> createState() => _WorkerInfoCardState();
}

class _WorkerInfoCardState extends State<WorkerInfoCard> {
  final TeamService _teamService = TeamService();
  final ShiftService _shiftService = ShiftService();

  TeamModel? _team;
  ShiftModel? _shift;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkerInfo();
  }

  Future<void> _loadWorkerInfo() async {
    try {
      setState(() => _isLoading = true);

      // Load team information
      if (widget.worker.teamId != null) {
        _team = await _teamService.getTeamById(widget.worker.teamId!);
      }

      // Load shift information
      if (widget.worker.shiftId != null) {
        _shift = await _shiftService.getShiftById(widget.worker.shiftId!);
      } else if (_team?.shiftId != null) {
        // If worker doesn't have individual shift, check team shift
        _shift = await _shiftService.getShiftById(_team!.shiftId!);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      AppLogger.error('Error loading worker info: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'My Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Worker Name
            _buildInfoRow(Icons.badge, 'Name', widget.worker.name),

            // Team Information
            if (_team != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.groups, 'Team', _team!.name),
              if (_team!.description != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    _team!.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.groups_outlined,
                'Team',
                'Not assigned to any team',
                valueColor: Colors.orange,
              ),
            ],

            // Shift Information
            if (_shift != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.schedule, 'Shift', _shift!.name),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Working Hours: ${_shift!.startTime} - ${_shift!.endTime}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Working Days: ${_getWorkingDaysText(_shift!.workDays)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Grace Period: ${_shift!.gracePeriodMinutes} minutes',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.schedule_outlined,
                'Shift',
                'No shift assigned',
                valueColor: Colors.orange,
              ),
            ],

            // Department (if available)
            if (widget.worker.department != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.business,
                'Department',
                widget.worker.department!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? Colors.grey[800],
              fontWeight: valueColor != null ? FontWeight.w500 : null,
            ),
          ),
        ),
      ],
    );
  }

  String _getWorkingDaysText(List<int> workDays) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return workDays.map((day) => dayNames[day - 1]).join(', ');
  }
}
