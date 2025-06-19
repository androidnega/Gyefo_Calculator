import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyefo_clocking_app/models/team_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/utils/app_theme.dart';

class TeamInfoCard extends StatelessWidget {
  const TeamInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<TeamModel>>(
      stream: _getManagerTeamsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError) {
          return _buildErrorCard('Error loading team data');
        }

        final teams = snapshot.data ?? [];
        if (teams.isEmpty) {
          return _buildNoTeamsCard();
        }

        return Column(
          children: teams.map((team) => _buildTeamCard(context, team)).toList(),
        );
      },
    );
  }

  Stream<List<TeamModel>> _getManagerTeamsStream(String managerId) {
    return FirebaseFirestore.instance
        .collection('teams')
        .where('managerId', isEqualTo: managerId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TeamModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Icon(Icons.group, color: AppTheme.primaryGreen),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading Team Information...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  LinearProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: AppTheme.errorRed),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.errorRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTeamsCard() {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Icon(Icons.group_off, color: AppTheme.textLight),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Teams Assigned',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create teams to manage workers effectively',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, TeamModel team) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.group,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (team.description != null && team.description!.isNotEmpty)
                        Text(
                          team.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textLight,
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
                _buildInfoChip(
                  icon: Icons.people,
                  label: '${team.memberIds.length} Members',
                  color: AppColors.clockInGreen,
                ),
                const SizedBox(width: 8),
                if (team.shiftId != null)
                  FutureBuilder<ShiftModel?>(
                    future: ShiftService().getShiftById(team.shiftId!),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final shift = snapshot.data!;
                        return _buildInfoChip(
                          icon: Icons.schedule,
                          label: shift.name,
                          color: AppColors.pendingOrange,
                        );
                      }
                      return _buildInfoChip(
                        icon: Icons.schedule_outlined,
                        label: 'No Shift',
                        color: AppTheme.textLight,
                      );
                    },
                  )
                else
                  _buildInfoChip(
                    icon: Icons.schedule_outlined,
                    label: 'No Shift',
                    color: AppTheme.textLight,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
