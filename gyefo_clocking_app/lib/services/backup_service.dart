import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:intl/intl.dart';

/// Service for handling data backup and sync operations
class BackupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a full backup of company data
  static Future<Map<String, dynamic>> createFullBackup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      AppLogger.info('Starting full backup creation...');

      Map<String, dynamic> backup = {
        'timestamp': FieldValue.serverTimestamp(),
        'backupDate': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'version': '1.0',
        'createdBy': user.uid,
      };

      // Backup users
      final usersSnapshot = await _firestore.collection('users').get();
      backup['users'] =
          usersSnapshot.docs
              .map((doc) => {'id': doc.id, 'data': doc.data()})
              .toList();

      // Backup attendance records
      List<Map<String, dynamic>> allAttendance = [];
      for (var userDoc in usersSnapshot.docs) {
        final attendanceSnapshot =
            await _firestore
                .collection('attendance')
                .doc(userDoc.id)
                .collection('records')
                .get();

        for (var attendanceDoc in attendanceSnapshot.docs) {
          allAttendance.add({
            'userId': userDoc.id,
            'recordId': attendanceDoc.id,
            'data': attendanceDoc.data(),
          });
        }
      }
      backup['attendance'] = allAttendance;

      // Backup shifts
      final shiftsSnapshot = await _firestore.collection('shifts').get();
      backup['shifts'] =
          shiftsSnapshot.docs
              .map((doc) => {'id': doc.id, 'data': doc.data()})
              .toList();

      // Backup teams
      final teamsSnapshot = await _firestore.collection('teams').get();
      backup['teams'] =
          teamsSnapshot.docs
              .map((doc) => {'id': doc.id, 'data': doc.data()})
              .toList();

      // Backup holidays
      final holidaysSnapshot = await _firestore.collection('holidays').get();
      backup['holidays'] =
          holidaysSnapshot.docs
              .map((doc) => {'id': doc.id, 'data': doc.data()})
              .toList();

      // Backup app settings
      final settingsSnapshot =
          await _firestore.collection('app_settings').get();
      backup['app_settings'] =
          settingsSnapshot.docs
              .map((doc) => {'id': doc.id, 'data': doc.data()})
              .toList();

      // Save backup to Firestore
      final backupDoc = await _firestore.collection('backups').add(backup);
      backup['backupId'] = backupDoc.id;

      AppLogger.success(
        'Full backup created successfully with ID: ${backupDoc.id}',
      );
      return backup;
    } catch (e) {
      AppLogger.error('Error creating full backup: $e');
      throw Exception('Failed to create backup: $e');
    }
  }

  /// Get list of available backups
  static Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    try {
      final backupsSnapshot =
          await _firestore
              .collection('backups')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .get();

      return backupsSnapshot.docs
          .map(
            (doc) => {
              'id': doc.id,
              'timestamp': doc.data()['timestamp'],
              'backupDate': doc.data()['backupDate'],
              'version': doc.data()['version'] ?? '1.0',
              'createdBy': doc.data()['createdBy'],
              'size': _calculateBackupSize(doc.data()),
            },
          )
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching available backups: $e');
      return [];
    }
  }

  /// Restore data from a backup
  static Future<void> restoreFromBackup(String backupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      AppLogger.info('Starting restore from backup: $backupId');

      final backupDoc =
          await _firestore.collection('backups').doc(backupId).get();
      if (!backupDoc.exists) {
        throw Exception('Backup not found');
      }

      final backupData = backupDoc.data()!;

      // Create restore log
      await _firestore.collection('restore_logs').add({
        'backupId': backupId,
        'restoredBy': user.uid,
        'restoredAt': FieldValue.serverTimestamp(),
        'status': 'in_progress',
      });

      // Restore users (be careful not to overwrite current admin)
      if (backupData['users'] != null) {
        for (var userData in backupData['users']) {
          if (userData['id'] != user.uid) {
            // Don't overwrite current admin
            await _firestore
                .collection('users')
                .doc(userData['id'])
                .set(userData['data']);
          }
        }
      }

      // Restore shifts
      if (backupData['shifts'] != null) {
        for (var shiftData in backupData['shifts']) {
          await _firestore
              .collection('shifts')
              .doc(shiftData['id'])
              .set(shiftData['data']);
        }
      }

      // Restore teams
      if (backupData['teams'] != null) {
        for (var teamData in backupData['teams']) {
          await _firestore
              .collection('teams')
              .doc(teamData['id'])
              .set(teamData['data']);
        }
      }

      // Restore holidays
      if (backupData['holidays'] != null) {
        for (var holidayData in backupData['holidays']) {
          await _firestore
              .collection('holidays')
              .doc(holidayData['id'])
              .set(holidayData['data']);
        }
      }

      // Restore attendance records
      if (backupData['attendance'] != null) {
        for (var attendanceData in backupData['attendance']) {
          await _firestore
              .collection('attendance')
              .doc(attendanceData['userId'])
              .collection('records')
              .doc(attendanceData['recordId'])
              .set(attendanceData['data']);
        }
      }

      // Update restore log
      await _firestore.collection('restore_logs').add({
        'backupId': backupId,
        'restoredBy': user.uid,
        'restoredAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      AppLogger.success('Backup restored successfully');
    } catch (e) {
      AppLogger.error('Error restoring backup: $e');

      // Log failed restore
      try {
        await _firestore.collection('restore_logs').add({
          'backupId': backupId,
          'restoredBy': _auth.currentUser?.uid,
          'restoredAt': FieldValue.serverTimestamp(),
          'status': 'failed',
          'error': e.toString(),
        });
      } catch (_) {}

      throw Exception('Failed to restore backup: $e');
    }
  }

  /// Delete old backups (keep only last N backups)
  static Future<void> cleanupOldBackups({int keepCount = 10}) async {
    try {
      final backupsSnapshot =
          await _firestore
              .collection('backups')
              .orderBy('timestamp', descending: true)
              .get();

      if (backupsSnapshot.docs.length > keepCount) {
        final docsToDelete = backupsSnapshot.docs.skip(keepCount).toList();

        for (var doc in docsToDelete) {
          await doc.reference.delete();
        }

        AppLogger.info('Cleaned up ${docsToDelete.length} old backups');
      }
    } catch (e) {
      AppLogger.error('Error cleaning up old backups: $e');
    }
  }

  /// Schedule automatic backup
  static Future<void> scheduleAutomaticBackup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check if backup is needed (once per day)
      final lastBackup =
          await _firestore
              .collection('backups')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      bool needsBackup = true;
      if (lastBackup.docs.isNotEmpty) {
        final lastBackupTime =
            lastBackup.docs.first.data()['timestamp'] as Timestamp;
        final hoursSinceLastBackup =
            DateTime.now().difference(lastBackupTime.toDate()).inHours;

        needsBackup = hoursSinceLastBackup >= 24; // Backup once per day
      }

      if (needsBackup) {
        AppLogger.info('Creating automatic backup...');
        await createFullBackup();
        await cleanupOldBackups();
      }
    } catch (e) {
      AppLogger.error('Error in automatic backup: $e');
    }
  }

  /// Export backup as downloadable data
  static Future<String> exportBackupData(String backupId) async {
    try {
      final backupDoc =
          await _firestore.collection('backups').doc(backupId).get();
      if (!backupDoc.exists) {
        throw Exception('Backup not found');
      }

      final backupData = backupDoc.data()!;

      // Convert to JSON string for export
      return backupData
          .toString(); // In a real app, you'd use proper JSON encoding
    } catch (e) {
      AppLogger.error('Error exporting backup data: $e');
      throw Exception('Failed to export backup: $e');
    }
  }

  /// Calculate backup size estimate
  static String _calculateBackupSize(Map<String, dynamic> backupData) {
    try {
      int totalItems = 0;

      if (backupData['users'] != null) {
        totalItems += (backupData['users'] as List).length;
      }
      if (backupData['attendance'] != null) {
        totalItems += (backupData['attendance'] as List).length;
      }
      if (backupData['shifts'] != null) {
        totalItems += (backupData['shifts'] as List).length;
      }
      if (backupData['teams'] != null) {
        totalItems += (backupData['teams'] as List).length;
      }
      if (backupData['holidays'] != null) {
        totalItems += (backupData['holidays'] as List).length;
      }

      // Rough estimate: ~1KB per item
      double sizeKB = totalItems * 1.0;
      if (sizeKB < 1024) {
        return '${sizeKB.toStringAsFixed(1)} KB';
      } else {
        return '${(sizeKB / 1024).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
