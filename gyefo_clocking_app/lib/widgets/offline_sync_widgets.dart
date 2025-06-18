import 'package:flutter/material.dart';
import '../services/offline_sync_service.dart';

class OfflineSyncStatusWidget extends StatelessWidget {
  final OfflineSyncService syncService;

  const OfflineSyncStatusWidget({super.key, required this.syncService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OfflineAttendanceEntry>>(
      stream: syncService.unsyncedEntriesStream,
      builder: (context, unsyncedSnapshot) {
        return StreamBuilder<SyncStatus>(
          stream: syncService.syncStatusStream,
          builder: (context, syncStatusSnapshot) {
            final unsyncedEntries = unsyncedSnapshot.data ?? [];
            final syncStatus = syncStatusSnapshot.data ?? SyncStatus.idle;

            if (unsyncedEntries.isEmpty && syncStatus != SyncStatus.syncing) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(syncStatus, unsyncedEntries.isNotEmpty),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _getStatusColor(
                    syncStatus,
                    unsyncedEntries.isNotEmpty,
                  ).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getStatusIcon(syncStatus),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getStatusTitle(syncStatus, unsyncedEntries.length),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.0,
                          ),
                        ),
                        if (unsyncedEntries.isNotEmpty)
                          Text(
                            _getStatusSubtitle(unsyncedEntries),
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (unsyncedEntries.isNotEmpty &&
                      syncStatus != SyncStatus.syncing)
                    IconButton(
                      icon: const Icon(Icons.sync, size: 20.0),
                      onPressed: () => syncService.forceSyncAll(),
                      tooltip: 'Force sync now',
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(SyncStatus status, bool hasUnsyncedEntries) {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue[100]!;
      case SyncStatus.error:
        return Colors.red[100]!;
      case SyncStatus.success:
        return hasUnsyncedEntries ? Colors.orange[100]! : Colors.green[100]!;
      case SyncStatus.idle:
        return hasUnsyncedEntries ? Colors.orange[100]! : Colors.grey[100]!;
    }
  }

  Widget _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 16.0,
          height: 16.0,
          child: CircularProgressIndicator(strokeWidth: 2.0),
        );
      case SyncStatus.error:
        return const Icon(Icons.error_outline, color: Colors.red, size: 20.0);
      case SyncStatus.success:
        return const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 20.0,
        );
      case SyncStatus.idle:
        return const Icon(Icons.cloud_queue, color: Colors.orange, size: 20.0);
    }
  }

  String _getStatusTitle(SyncStatus status, int unsyncedCount) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing attendance...';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.success:
        return unsyncedCount > 0 ? 'Partial sync completed' : 'All data synced';
      case SyncStatus.idle:
        return unsyncedCount > 0 ? 'Offline data pending' : 'Ready';
    }
  }

  String _getStatusSubtitle(List<OfflineAttendanceEntry> entries) {
    if (entries.isEmpty) return '';

    final count = entries.length;
    final oldestEntry = entries.isNotEmpty ? entries.first : null;

    if (oldestEntry != null) {
      final hoursAgo = DateTime.now().difference(oldestEntry.timestamp).inHours;
      if (hoursAgo > 24) {
        final daysAgo = (hoursAgo / 24).floor();
        return '$count entries pending (oldest: ${daysAgo}d ago)';
      } else if (hoursAgo > 0) {
        return '$count entries pending (oldest: ${hoursAgo}h ago)';
      } else {
        final minutesAgo =
            DateTime.now().difference(oldestEntry.timestamp).inMinutes;
        return '$count entries pending (oldest: ${minutesAgo}m ago)';
      }
    }

    return '$count entries pending sync';
  }
}

class OfflineSyncDebugScreen extends StatefulWidget {
  final OfflineSyncService syncService;

  const OfflineSyncDebugScreen({super.key, required this.syncService});

  @override
  State<OfflineSyncDebugScreen> createState() => _OfflineSyncDebugScreenState();
}

class _OfflineSyncDebugScreenState extends State<OfflineSyncDebugScreen> {
  Map<String, dynamic>? _syncStats;

  @override
  void initState() {
    super.initState();
    _loadSyncStats();
  }

  Future<void> _loadSyncStats() async {
    final stats = await widget.syncService.getSyncStats();
    setState(() {
      _syncStats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Sync Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSyncStats,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sync Status
            OfflineSyncStatusWidget(syncService: widget.syncService),

            const SizedBox(height: 20.0),

            // Sync Statistics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sync Statistics',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    if (_syncStats != null) ...[
                      _buildStatRow(
                        'Unsynced entries',
                        '${_syncStats!['unsyncedCount']}',
                      ),
                      _buildStatRow(
                        'Last sync',
                        _formatDateTime(_syncStats!['lastSyncTime']),
                      ),
                      _buildStatRow(
                        'Last sync status',
                        '${_syncStats!['lastSyncStatus']}',
                      ),
                      _buildStatRow(
                        'Oldest unsynced',
                        _formatDateTime(_syncStats!['oldestUnsyncedTimestamp']),
                      ),
                    ] else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20.0),

            // Unsynced Entries
            StreamBuilder<List<OfflineAttendanceEntry>>(
              stream: widget.syncService.unsyncedEntriesStream,
              builder: (context, snapshot) {
                final entries = snapshot.data ?? [];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unsynced Entries (${entries.length})',
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        if (entries.isEmpty)
                          const Text('No unsynced entries')
                        else
                          ...entries.map((entry) => _buildEntryTile(entry)),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20.0),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.syncService.forceSyncAll(),
                    child: const Text('Force Sync All'),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.syncService.cleanupOldEntries(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Cleanup Old'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12.0),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showClearDataDialog(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Clear All Offline Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEntryTile(OfflineAttendanceEntry entry) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.action.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                _formatDateTime(entry.timestamp),
                style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
              ),
            ],
          ),
          if (entry.locationAddress != null) ...[
            const SizedBox(height: 4.0),
            Text(
              'Location: ${entry.locationAddress}',
              style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Offline Data'),
            content: const Text(
              'This will permanently delete all offline attendance data. '
              'Are you sure you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await widget.syncService.clearAllOfflineData();
                  if (mounted) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadSyncStats();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Offline data cleared')),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }
}
