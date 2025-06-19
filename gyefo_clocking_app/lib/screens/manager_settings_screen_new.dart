import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/offline_sync_service.dart';
import '../services/backup_service.dart';
import '../widgets/offline_sync_widgets.dart';
import '../widgets/logout_confirmation_dialog.dart';
import '../themes/app_themes.dart';

class ManagerSettingsScreen extends StatefulWidget {
  final OfflineSyncService? offlineSyncService;

  const ManagerSettingsScreen({super.key, this.offlineSyncService});

  @override
  State<ManagerSettingsScreen> createState() => _ManagerSettingsScreenState();
}

class _ManagerSettingsScreenState extends State<ManagerSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            user?.displayName?.substring(0, 1).toUpperCase() ??
                                user?.email?.substring(0, 1).toUpperCase() ??
                                'M',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Manager',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Manager',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sync Status Section
            if (widget.offlineSyncService != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sync Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OfflineSyncStatusWidget(
                        syncService: widget.offlineSyncService!,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => OfflineSyncDebugScreen(
                                        syncService: widget.offlineSyncService!,
                                      ),
                                ),
                              ),
                          icon: const Icon(Icons.bug_report),
                          label: const Text('Sync Debug'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Settings Options
            Card(
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () => _showNotificationSettings(context),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.download,
                    title: 'Export Data',
                    subtitle: 'Download attendance reports',
                    onTap: () => _showExportOptions(context),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.security,
                    title: 'Privacy & Security',
                    subtitle: 'Data protection settings',
                    onTap: () => _showPrivacySettings(context),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.backup,
                    title: 'Backup & Sync',
                    subtitle: 'Data backup preferences',
                    onTap: () => _showBackupSettings(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Support Section
            Card(
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'Get help and documentation',
                    onTap: () => _showHelpDialog(context),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.feedback,
                    title: 'Send Feedback',
                    subtitle: 'Help us improve the app',
                    onTap: () => _sendFeedback(),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'Choose your preferred theme',
                    onTap: () => _showThemeDialog(context),
                  ),
                  const Divider(height: 1),
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    title: 'About',
                    subtitle: 'App version and information',
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Notification Settings'),
            content: const Text(
              'Configure your notification preferences for attendance alerts, '
              'flagged records, and justification requests.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Export Options'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export attendance data in various formats:'),
                SizedBox(height: 12),
                Text('• CSV for spreadsheet analysis'),
                Text('• PDF for printable reports'),
                Text('• Custom date ranges'),
                Text('• Worker and flag filters'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Privacy & Security'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your data is protected with:'),
                SizedBox(height: 12),
                Text('• End-to-end encryption'),
                Text('• Role-based access control'),
                Text('• Company data isolation'),
                Text('• Secure cloud storage'),
                Text('• Regular security audits'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showBackupSettings(BuildContext context) {
    showDialog(context: context, builder: (context) => BackupSettingsDialog());
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Help & Support'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Get help with:'),
                SizedBox(height: 12),
                Text('• Managing worker accounts'),
                Text('• Reviewing attendance records'),
                Text('• Understanding analytics'),
                Text('• Troubleshooting issues'),
                SizedBox(height: 12),
                Text('Contact support:'),
                Text('Email: support@manuelcode.info'),
                Text('Phone: +1233 54 106 92 41'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _launchEmail();
                },
                child: const Text('Contact Support'),
              ),
            ],
          ),
    );
  }

  void _sendFeedback() async {
    const email = 'feedback@gyefo.com';
    const subject = 'Gyefo Clocking App Feedback';
    const body =
        'Hi Gyefo Team,\n\nI have feedback about the clocking app:\n\n';

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email app. Please contact feedback@gyefo.com',
            ),
          ),
        );
      }
    }
  }

  void _launchEmail() async {
    const email = 'support@manuelcode.info';
    const subject = 'Gyefo Clocking App Support Request';
    const body = 'Hi Support Team,\n\nI need help with:\n\n';

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Theme'),
            content: ValueListenableBuilder(
              valueListenable: AppThemes.themeNotifier,
              builder: (_, ThemeMode currentMode, __) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      title: const Text('System'),
                      subtitle: const Text('Follow system setting'),
                      value: ThemeMode.system,
                      groupValue: currentMode,
                      onChanged: (ThemeMode? value) {
                        if (value != null) {
                          AppThemes.setThemeMode(value);
                          Navigator.pop(context);
                        }
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light'),
                      subtitle: const Text('Always use light theme'),
                      value: ThemeMode.light,
                      groupValue: currentMode,
                      onChanged: (ThemeMode? value) {
                        if (value != null) {
                          AppThemes.setThemeMode(value);
                          Navigator.pop(context);
                        }
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark'),
                      subtitle: const Text('Always use dark theme'),
                      value: ThemeMode.dark,
                      groupValue: currentMode,
                      onChanged: (ThemeMode? value) {
                        if (value != null) {
                          AppThemes.setThemeMode(value);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AboutDialog(
            applicationName: 'Gyefo Clocking System',
            applicationVersion: '2.0.0',
            applicationIcon: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset('assets/icon/icon.png', width: 50, height: 50),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Modern employee time tracking and attendance management system.',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Features:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('• GPS-based clock in/out'),
                    Text('• Real-time attendance tracking'),
                    Text('• Team management'),
                    Text('• Offline mode support'),
                    Text('• Push notifications'),
                    Text('• Dark mode support'),
                    SizedBox(height: 16),
                    Text(
                      '© 2023-2024 Gyefo Systems\nAll rights reserved.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _logout();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
    );
  }

  Future<void> _logout() async {
    try {
      // Show logout confirmation dialog
      final confirmed = await LogoutConfirmationDialog.show(context);
      if (confirmed != true) return;

      // Session cleanup is handled by the dialog
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class BackupSettingsDialog extends StatefulWidget {
  const BackupSettingsDialog({super.key});

  @override
  State<BackupSettingsDialog> createState() => _BackupSettingsDialogState();
}

class _BackupSettingsDialogState extends State<BackupSettingsDialog> {
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = false;
  bool _isCreatingBackup = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final backups = await BackupService.getAvailableBackups();
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Error loading backups: $e');
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isCreatingBackup = true);
    try {
      await BackupService.createFullBackup();
      await _loadBackups(); // Refresh the list
      _showSuccessMessage('Backup created successfully!');
    } catch (e) {
      _showErrorMessage('Error creating backup: $e');
    } finally {
      setState(() => _isCreatingBackup = false);
    }
  }

  Future<void> _restoreBackup(String backupId) async {
    final confirmed = await _showConfirmationDialog(
      'Restore Backup',
      'Are you sure you want to restore this backup? This will overwrite current data.',
    );

    if (confirmed != true) return;
    try {
      setState(() => _isLoading = true);
      await BackupService.restoreFromBackup(backupId);
      if (mounted) {
        _showSuccessMessage('Backup restored successfully!');
        Navigator.of(context).pop(); // Close dialog
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Error restoring backup: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scheduleAutomaticBackup() async {
    try {
      await BackupService.scheduleAutomaticBackup();
      _showSuccessMessage('Automatic backup scheduled!');
    } catch (e) {
      _showErrorMessage('Error scheduling backup: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<bool?> _showConfirmationDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backup & Sync'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingBackup ? null : _createBackup,
                    icon:
                        _isCreatingBackup
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.backup),
                    label: Text(
                      _isCreatingBackup ? 'Creating...' : 'Create Backup',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scheduleAutomaticBackup,
                    icon: const Icon(Icons.schedule),
                    label: const Text('Auto Backup'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Backups list
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Available Backups:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _backups.isEmpty
                      ? const Center(
                        child: Text(
                          'No backups available.\nCreate your first backup!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _backups.length,
                        itemBuilder: (context, index) {
                          final backup = _backups[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.folder_zip),
                              title: Text(
                                backup['backupDate'] ?? 'Unknown Date',
                              ),
                              subtitle: Text(
                                'Size: ${backup['size']} • Version: ${backup['version']}',
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder:
                                    (context) => [
                                      PopupMenuItem(
                                        value: 'restore',
                                        child: const Text('Restore'),
                                      ),
                                      PopupMenuItem(
                                        value: 'export',
                                        child: const Text('Export'),
                                      ),
                                    ],
                                onSelected: (value) {
                                  if (value == 'restore') {
                                    _restoreBackup(backup['id']);
                                  } else if (value == 'export') {
                                    // Export functionality would go here
                                    _showErrorMessage(
                                      'Export feature coming soon!',
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
