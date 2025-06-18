import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/team_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/services/team_service.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/services/auth_service.dart';
import 'package:gyefo_clocking_app/screens/team_form_screen.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class TeamDetailScreen extends StatefulWidget {
  final TeamModel team;

  const TeamDetailScreen({super.key, required this.team});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final TeamService _teamService = TeamService();
  final ShiftService _shiftService = ShiftService();
  final AuthService _authService = AuthService();

  List<UserModel> _teamMembers = [];
  ShiftModel? _assignedShift;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamDetails();
  }

  Future<void> _loadTeamDetails() async {
    setState(() => _isLoading = true);

    try {
      // Load team members
      final members = <UserModel>[];
      for (final memberId in widget.team.memberIds) {
        final user = await _authService.getWorkerById(memberId);
        if (user != null) {
          members.add(user);
        }
      }

      // Load assigned shift
      ShiftModel? shift;
      if (widget.team.shiftId != null) {
        shift = await _shiftService.getShiftById(widget.team.shiftId!);
      }

      setState(() {
        _teamMembers = members;
        _assignedShift = shift;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading team details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddMemberDialog() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add),
                SizedBox(width: 8),
                Text('Add Team Member'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This feature allows managers to add workers to teams.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coming Soon:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Search and select available workers\n'
                        '• Bulk member assignment\n'
                        '• Role-based team permissions\n'
                        '• Integration with worker profiles',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // For now, just show that the feature is planned
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Team member management coming in next update!',
                      ),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _removeMemberFromTeam(UserModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Member'),
            content: Text('Remove ${member.name} from the team?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _teamService.removeWorkerFromTeam(widget.team.id, member.uid);
        _loadTeamDetails(); // Refresh the data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member removed from team'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        AppLogger.error('Error removing member: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing member: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final result = await navigator.push(
                MaterialPageRoute(
                  builder: (context) => TeamFormScreen(team: widget.team),
                ),
              );

              if (result == true && mounted) {
                // Refresh the team data and notify parent
                navigator.pop(true);
              }
            },
            tooltip: 'Edit Team',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTeamInfoCard(),
                    const SizedBox(height: 16),
                    if (_assignedShift != null) ...[
                      _buildShiftInfoCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildMembersCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildTeamInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Team Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.label, 'Name', widget.team.name),
            if (widget.team.description != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.description,
                'Description',
                widget.team.description!,
              ),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.info_outline,
              'Status',
              widget.team.isActive ? 'Active' : 'Inactive',
              valueColor: widget.team.isActive ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.people,
              'Total Members',
              '${widget.team.memberIds.length}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Assigned Shift',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.label, 'Shift Name', _assignedShift!.name),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'Working Hours',
              '${_assignedShift!.startTime} - ${_assignedShift!.endTime}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Working Days',
              _assignedShift!.workDays
                  .map((day) => _getDayName(day))
                  .join(', '),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Team Members (${_teamMembers.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () {
                    _showAddMemberDialog();
                  },
                  tooltip: 'Add Member',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_teamMembers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No team members yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add members to get started',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _teamMembers.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final member = _teamMembers[index];
                  return _buildMemberTile(member);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(UserModel member) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: Text(
          '${member.name[0]}${member.name.split(' ').length > 1 ? member.name.split(' ')[1][0] : ''}',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(member.name),
      subtitle: Text(member.email ?? 'No email'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'remove':
              _removeMemberFromTeam(member);
              break;
          }
        },
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Remove from team',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
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

  String _getDayName(int day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[day - 1];
  }
}
