import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/team_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all teams (for managers to see all teams in the organization)
  Future<List<TeamModel>> getAllTeams() async {
    try {
      final snapshot = await _firestore
          .collection('teams')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => TeamModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching all teams: $e');
      return [];
    }
  }

  /// Get all teams for a manager
  Future<List<TeamModel>> getManagerTeams(String managerId) async {
    try {
      final snapshot = await _firestore
          .collection('teams')
          .where('managerId', isEqualTo: managerId)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => TeamModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching manager teams: $e');
      return [];
    }
  }

  /// Get team by ID
  Future<TeamModel?> getTeamById(String teamId) async {
    try {
      final doc = await _firestore.collection('teams').doc(teamId).get();
      if (doc.exists) {
        return TeamModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching team $teamId: $e');
      return null;
    }
  }

  /// Get worker's team
  Future<TeamModel?> getWorkerTeam(String workerId) async {
    try {
      final snapshot = await _firestore
          .collection('teams')
          .where('memberIds', arrayContains: workerId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return TeamModel.fromMap(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching worker team: $e');
      return null;
    }
  }

  /// Create new team
  Future<String?> createTeam(TeamModel team) async {
    try {
      final docRef = await _firestore.collection('teams').add(team.toMap());
      AppLogger.success('Team created successfully: ${team.name}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Error creating team: $e');
      return null;
    }
  }

  /// Update team
  Future<bool> updateTeam(TeamModel team) async {
    try {
      await _firestore
          .collection('teams')
          .doc(team.id)
          .update(team.toMap());
      AppLogger.success('Team updated successfully: ${team.name}');
      return true;
    } catch (e) {
      AppLogger.error('Error updating team: $e');
      return false;
    }
  }

  /// Add worker to team
  Future<bool> addWorkerToTeam(String teamId, String workerId) async {
    try {
      // First remove worker from any existing team
      await removeWorkerFromAllTeams(workerId);

      // Add to new team
      await _firestore.collection('teams').doc(teamId).update({
        'memberIds': FieldValue.arrayUnion([workerId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update worker's teamId
      await _firestore.collection('users').doc(workerId).update({
        'teamId': teamId,
      });

      AppLogger.success('Worker added to team successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error adding worker to team: $e');
      return false;
    }
  }

  /// Remove worker from team
  Future<bool> removeWorkerFromTeam(String teamId, String workerId) async {
    try {
      await _firestore.collection('teams').doc(teamId).update({
        'memberIds': FieldValue.arrayRemove([workerId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update worker's teamId
      await _firestore.collection('users').doc(workerId).update({
        'teamId': null,
      });

      AppLogger.success('Worker removed from team successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error removing worker from team: $e');
      return false;
    }
  }

  /// Remove worker from all teams (helper method)
  Future<void> removeWorkerFromAllTeams(String workerId) async {
    try {
      final snapshot = await _firestore
          .collection('teams')
          .where('memberIds', arrayContains: workerId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'memberIds': FieldValue.arrayRemove([workerId]),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      AppLogger.error('Error removing worker from all teams: $e');
    }
  }

  /// Get team members with their details
  Future<List<UserModel>> getTeamMembers(String teamId) async {
    try {
      final team = await getTeamById(teamId);
      if (team == null || team.memberIds.isEmpty) return [];

      final List<UserModel> members = [];
      for (final memberId in team.memberIds) {
        final userDoc = await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          members.add(UserModel.fromMap(userDoc.data()!, userDoc.id));
        }
      }

      return members;
    } catch (e) {
      AppLogger.error('Error fetching team members: $e');
      return [];
    }
  }

  /// Get unassigned workers
  Future<List<UserModel>> getUnassignedWorkers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .where('isActive', isEqualTo: true)
          .get();

      List<UserModel> allWorkers = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();

      // Filter out workers who are already in teams
      List<UserModel> unassigned = [];
      for (final worker in allWorkers) {
        if (worker.teamId == null || worker.teamId!.isEmpty) {
          unassigned.add(worker);
        }
      }

      return unassigned;
    } catch (e) {
      AppLogger.error('Error fetching unassigned workers: $e');
      return [];
    }
  }

  /// Delete team
  Future<bool> deleteTeam(String teamId) async {
    try {
      // First remove all members from team
      final team = await getTeamById(teamId);
      if (team != null) {
        for (final memberId in team.memberIds) {
          await removeWorkerFromTeam(teamId, memberId);
        }
      }

      // Delete the team
      await _firestore.collection('teams').doc(teamId).delete();
      AppLogger.success('Team deleted successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error deleting team: $e');
      return false;
    }
  }

  /// Stream of teams for real-time updates
  Stream<List<TeamModel>> managerTeamsStream(String managerId) {
    return _firestore
        .collection('teams')
        .where('managerId', isEqualTo: managerId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get team statistics
  Future<Map<String, dynamic>> getTeamStats(String teamId) async {
    try {
      final team = await getTeamById(teamId);
      if (team == null) return {};

      final members = await getTeamMembers(teamId);
      int activeMembers = members.where((member) => member.isActive).length;

      // Calculate today's attendance for team
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      int clockedInToday = 0;
      for (final member in members) {
        final attendanceSnapshot = await _firestore
            .collection('attendance')
            .doc(member.uid)
            .collection('records')
            .where('date', isEqualTo: todayString)
            .where('clockOut', isNull: true)
            .limit(1)
            .get();

        if (attendanceSnapshot.docs.isNotEmpty) {
          clockedInToday++;
        }
      }

      return {
        'totalMembers': members.length,
        'activeMembers': activeMembers,
        'clockedInToday': clockedInToday,
        'attendanceRate': members.isNotEmpty 
            ? (clockedInToday / members.length * 100).round()
            : 0,
      };
    } catch (e) {
      AppLogger.error('Error calculating team stats: $e');
      return {};
    }
  }
}
