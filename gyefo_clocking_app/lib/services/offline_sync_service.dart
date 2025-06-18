import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// Sync status enum
enum SyncStatus { idle, syncing, success, error }

class OfflineAttendanceEntry {
  final String id;
  final String userId;
  final DateTime timestamp;
  final String action; // 'clock_in' or 'clock_out'
  final String? shiftId;
  final String? teamId;
  final String? companyId;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final Map<String, dynamic>? metadata;
  final bool synced;
  final DateTime createdAt;

  OfflineAttendanceEntry({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.action,
    this.shiftId,
    this.teamId,
    this.companyId,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.metadata,
    this.synced = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'action': action,
      'shiftId': shiftId,
      'teamId': teamId,
      'companyId': companyId,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
      'metadata': metadata,
      'synced': synced,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory OfflineAttendanceEntry.fromJson(Map<String, dynamic> json) {
    return OfflineAttendanceEntry(
      id: json['id'],
      userId: json['userId'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      action: json['action'],
      shiftId: json['shiftId'],
      teamId: json['teamId'],
      companyId: json['companyId'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      locationAddress: json['locationAddress'],
      metadata: json['metadata'],
      synced: json['synced'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
    );
  }
}

class OfflineSyncService {
  static const String _offlineEntriesKey = 'offline_attendance_entries';
  static const String _syncStatusKey = 'last_sync_status';
  static const String _lastSyncTimeKey = 'last_sync_time';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  Timer? _syncTimer;
  StreamController<List<OfflineAttendanceEntry>>? _unsyncedEntriesController;
  StreamController<SyncStatus>? _syncStatusController;

  Stream<List<OfflineAttendanceEntry>> get unsyncedEntriesStream {
    _unsyncedEntriesController ??=
        StreamController<List<OfflineAttendanceEntry>>.broadcast();
    return _unsyncedEntriesController!.stream;
  }

  Stream<SyncStatus> get syncStatusStream {
    _syncStatusController ??= StreamController<SyncStatus>.broadcast();
    return _syncStatusController!.stream;
  }

  Future<void> initialize() async {
    // Start periodic sync every 5 minutes
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncOfflineEntries(),
    );

    // Initial sync attempt
    await syncOfflineEntries();

    // Emit current unsynced entries
    final entries = await getUnsyncedEntries();
    _unsyncedEntriesController?.add(entries);
  }

  void dispose() {
    _syncTimer?.cancel();
    _unsyncedEntriesController?.close();
    _syncStatusController?.close();
  }

  /// Save attendance entry for offline processing
  Future<String> saveOfflineAttendance({
    required String action,
    String? shiftId,
    String? teamId,
    String? companyId,
    Position? location,
    String? locationAddress,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final entry = OfflineAttendanceEntry(
      id: _generateEntryId(),
      userId: user.uid,
      timestamp: DateTime.now(),
      action: action,
      shiftId: shiftId,
      teamId: teamId,
      companyId: companyId,
      latitude: location?.latitude,
      longitude: location?.longitude,
      locationAddress: locationAddress,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    await _saveEntryLocally(entry);

    // Emit updated unsynced entries
    final entries = await getUnsyncedEntries();
    _unsyncedEntriesController?.add(entries);

    // Try immediate sync if online
    if (await _isOnline()) {
      unawaited(syncOfflineEntries());
    }

    return entry.id;
  }

  /// Get all unsynced entries
  Future<List<OfflineAttendanceEntry>> getUnsyncedEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_offlineEntriesKey) ?? [];

    return entriesJson
        .map((json) => OfflineAttendanceEntry.fromJson(jsonDecode(json)))
        .where((entry) => !entry.synced)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final unsyncedEntries = await getUnsyncedEntries();
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getInt(_lastSyncTimeKey);
    final lastSyncStatus = prefs.getString(_syncStatusKey) ?? 'never';

    return {
      'unsyncedCount': unsyncedEntries.length,
      'oldestUnsyncedTimestamp':
          unsyncedEntries.isNotEmpty ? unsyncedEntries.first.timestamp : null,
      'lastSyncTime':
          lastSyncTime != null
              ? DateTime.fromMillisecondsSinceEpoch(lastSyncTime)
              : null,
      'lastSyncStatus': lastSyncStatus,
    };
  }

  /// Sync all offline entries to Firestore
  Future<bool> syncOfflineEntries() async {
    if (!await _isOnline()) {
      _setSyncStatus(SyncStatus.error);
      return false;
    }

    _setSyncStatus(SyncStatus.syncing);

    try {
      final unsyncedEntries = await getUnsyncedEntries();

      if (unsyncedEntries.isEmpty) {
        _setSyncStatus(SyncStatus.success);
        await _updateLastSyncTime();
        return true;
      }

      final batch = _firestore.batch();
      final List<String> syncedEntryIds = [];

      for (final entry in unsyncedEntries) {
        try {
          // Check for duplicate prevention
          if (await _isDuplicateEntry(entry)) {
            syncedEntryIds.add(entry.id);
            continue;
          }

          // Create Firestore document
          final docRef = _firestore.collection('attendance').doc();
          final attendanceData = {
            'userId': entry.userId,
            'clockIn':
                entry.action == 'clock_in'
                    ? Timestamp.fromDate(entry.timestamp)
                    : null,
            'clockOut':
                entry.action == 'clock_out'
                    ? Timestamp.fromDate(entry.timestamp)
                    : null,
            'shiftId': entry.shiftId,
            'teamId': entry.teamId,
            'companyId': entry.companyId,
            'locationIn':
                entry.action == 'clock_in' && entry.latitude != null
                    ? GeoPoint(entry.latitude!, entry.longitude!)
                    : null,
            'locationOut':
                entry.action == 'clock_out' && entry.latitude != null
                    ? GeoPoint(entry.latitude!, entry.longitude!)
                    : null,
            'locationAddressIn':
                entry.action == 'clock_in' ? entry.locationAddress : null,
            'locationAddressOut':
                entry.action == 'clock_out' ? entry.locationAddress : null,
            'syncedFromOffline': true,
            'offlineTimestamp': Timestamp.fromDate(entry.timestamp),
            'metadata': entry.metadata,
            'createdAt': FieldValue.serverTimestamp(),
          };

          batch.set(docRef, attendanceData);
          syncedEntryIds.add(entry.id);
        } catch (e) {
          print('Error preparing entry ${entry.id} for sync: $e');
          // Continue with other entries
        }
      }

      // Commit batch
      await batch.commit();

      // Mark entries as synced locally
      await _markEntriesAsSynced(syncedEntryIds);

      _setSyncStatus(SyncStatus.success);
      await _updateLastSyncTime();

      // Emit updated unsynced entries
      final remainingEntries = await getUnsyncedEntries();
      _unsyncedEntriesController?.add(remainingEntries);

      return true;
    } catch (e) {
      print('Sync error: $e');
      _setSyncStatus(SyncStatus.error);
      await _saveSyncError(e.toString());
      return false;
    }
  }

  /// Check if there's internet connectivity
  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Generate unique entry ID
  String _generateEntryId() {
    return 'offline_${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser?.uid ?? 'unknown'}';
  }

  /// Save entry to local storage
  Future<void> _saveEntryLocally(OfflineAttendanceEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_offlineEntriesKey) ?? [];

    entriesJson.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_offlineEntriesKey, entriesJson);
  }

  /// Mark entries as synced
  Future<void> _markEntriesAsSynced(List<String> entryIds) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_offlineEntriesKey) ?? [];

    final updatedEntries =
        entriesJson.map((jsonStr) {
          final entry = OfflineAttendanceEntry.fromJson(jsonDecode(jsonStr));
          if (entryIds.contains(entry.id)) {
            return jsonEncode(
              OfflineAttendanceEntry(
                id: entry.id,
                userId: entry.userId,
                timestamp: entry.timestamp,
                action: entry.action,
                shiftId: entry.shiftId,
                teamId: entry.teamId,
                companyId: entry.companyId,
                latitude: entry.latitude,
                longitude: entry.longitude,
                locationAddress: entry.locationAddress,
                metadata: entry.metadata,
                synced: true,
                createdAt: entry.createdAt,
              ).toJson(),
            );
          }
          return jsonStr;
        }).toList();

    await prefs.setStringList(_offlineEntriesKey, updatedEntries);
  }

  /// Check for duplicate entries to prevent double-clocking
  Future<bool> _isDuplicateEntry(OfflineAttendanceEntry entry) async {
    try {
      // Check for existing attendance within 1 minute window
      final query = _firestore
          .collection('attendance')
          .where('userId', isEqualTo: entry.userId)
          .where(
            'offlineTimestamp',
            isGreaterThan: Timestamp.fromDate(
              entry.timestamp.subtract(const Duration(minutes: 1)),
            ),
          )
          .where(
            'offlineTimestamp',
            isLessThan: Timestamp.fromDate(
              entry.timestamp.add(const Duration(minutes: 1)),
            ),
          );

      final snapshot = await query.get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      // If query fails, assume not duplicate to avoid blocking sync
      return false;
    }
  }

  /// Update sync status
  void _setSyncStatus(SyncStatus status) {
    _syncStatusController?.add(status);
  }

  /// Update last sync time
  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncTimeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_syncStatusKey, 'success');
  }

  /// Save sync error for debugging
  Future<void> _saveSyncError(String error) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncStatusKey, 'error: $error');
  }

  /// Clean up old synced entries (older than 7 days)
  Future<void> cleanupOldEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_offlineEntriesKey) ?? [];
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

    final activeEntries =
        entriesJson
            .map((json) => OfflineAttendanceEntry.fromJson(jsonDecode(json)))
            .where(
              (entry) => !entry.synced || entry.createdAt.isAfter(cutoffDate),
            )
            .map((entry) => jsonEncode(entry.toJson()))
            .toList();

    await prefs.setStringList(_offlineEntriesKey, activeEntries);
  }

  /// Force sync all entries
  Future<bool> forceSyncAll() async {
    return await syncOfflineEntries();
  }

  /// Clear all offline data (for testing/debugging)
  Future<void> clearAllOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineEntriesKey);
    await prefs.remove(_syncStatusKey);
    await prefs.remove(_lastSyncTimeKey);

    _unsyncedEntriesController?.add([]);
  }
}

// Helper to avoid unawaited futures warning
void unawaited(Future<void> future) {
  // Intentionally ignore the future
}
