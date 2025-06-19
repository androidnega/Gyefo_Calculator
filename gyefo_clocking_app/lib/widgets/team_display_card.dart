import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyefo_clocking_app/models/team_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/services/team_service.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/screens/team_management_screen.dart';

class TeamDisplayCard extends StatefulWidget {
  const TeamDisplayCard({super.key});

  @override
  State<TeamDisplayCard> createState() => _TeamDisplayCardState();
}

class _TeamDisplayCardState extends State<TeamDisplayCard> {
  final TeamService _teamService = TeamService();
  final ShiftService _shiftService = ShiftService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<TeamModel>>(
      stream: _teamService.managerTeamsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading teams',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to refresh',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        final teams = snapshot.data ?? [];

        if (teams.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'No Teams Created',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Create your first team to organize workers',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToTeamManagement(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Team'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
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
                    Icon(
                      Icons.people,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Teams',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _navigateToTeamManagement(),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (teams.length <= 3)
                  // Show detailed cards for few teams
                  ...teams.map((team) => _buildDetailedTeamCard(team))
                else
                  // Show compact list for many teams
                  _buildCompactTeamsList(teams),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailedTeamCard(TeamModel team) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  team.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: team.isActive
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  team.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    color: team.isActive ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip(
                Icons.person,
                '${team.memberIds.length} members',
                Colors.blue,
              ),
              const SizedBox(width: 8),
              FutureBuilder<ShiftModel?>(
                future: team.shiftId != null
                    ? _shiftService.getShiftById(team.shiftId!)
                    : null,
                builder: (context, shiftSnapshot) {
                  if (team.shiftId == null) {
                    return _buildInfoChip(
                      Icons.schedule_outlined,
                      'No shift',
                      Colors.orange,
                    );
                  }
                  
                  if (shiftSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildInfoChip(
                      Icons.schedule,
                      'Loading...',
                      Colors.grey,
                    );
                  }
                  
                  final shift = shiftSnapshot.data;
                  if (shift == null) {
                    return _buildInfoChip(
                      Icons.error_outline,
                      'Invalid shift',
                      Colors.red,
                    );
                  }
                  
                  return _buildInfoChip(
                    Icons.schedule,
                    '${shift.startTime}-${shift.endTime}',
                    Colors.green,
                  );
                },
              ),
            ],
          ),
          if (team.description != null && team.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              team.description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactTeamsList(List<TeamModel> teams) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.groups,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${teams.length} Teams Active',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${teams.fold<int>(0, (sum, team) => sum + team.memberIds.length)} Members',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...teams.take(2).map((team) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  team.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${team.memberIds.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        )),
        if (teams.length > 2)
          Container(
            padding: const EdgeInsets.all(8),
            child: Text(
              '+${teams.length - 2} more teams',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
  Widget _buildInfoChip(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color[700]),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTeamManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TeamManagementScreen(),
      ),
    );
  }
}
