import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:gyefo_clocking_app/screens/work_location_setup_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ManagerSettingsScreen extends StatelessWidget {
  const ManagerSettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.orange),
              SizedBox(width: 8),
              Text('Confirm Logout'),
            ],
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        await FirebaseAuth.instance.signOut();
        AppLogger.info('Manager logged out successfully');
        
        if (context.mounted) {
          // Navigate to login and clear the stack
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Help & Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need assistance with the Gyefo Clocking App?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            
            _buildContactInfo(
              icon: Icons.email,
              label: 'Email Support',
              value: 'support@gyefo.com',
              onTap: () => _launchEmail('support@gyefo.com'),
            ),
            const SizedBox(height: 12),
            
            _buildContactInfo(
              icon: Icons.phone,
              label: 'Phone Support',
              value: '0500000000',
              onTap: () => _launchPhone('0500000000'),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Support Hours',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monday - Friday: 8:00 AM - 6:00 PM\nSaturday: 9:00 AM - 2:00 PM',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('About Gyefo Clocking App'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gyefo Clocking App',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Version 1.0.0'),
            const SizedBox(height: 16),
            const Text(
              'A comprehensive attendance management system designed to help businesses track and manage employee working hours efficiently.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Features:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Real-time clock in/out tracking\n'
                    '• Comprehensive reporting\n'
                    '• Calendar view of attendance\n'
                    '• Export functionality (CSV/PDF)\n'
                    '• Smart notifications\n'
                    '• Manager dashboard with analytics',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue.shade600),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Gyefo Clocking App Support',
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(
                          Icons.person,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manager Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (user?.email != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                user!.email!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
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

          // Settings Options
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.blue),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Get help and contact support'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showHelp(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.green),
                  title: const Text('About'),
                  subtitle: const Text('App version and information'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showAbout(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.red),
                  title: const Text('Work Location Setup'),
                  subtitle: const Text('Set up and manage work locations'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const WorkLocationSetupScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Section
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red.shade700),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text('Sign out of your account'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.red.shade700,
              ),
              onTap: () => _logout(context),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Footer
          Center(
            child: Column(
              children: [
                Text(
                  'Gyefo Clocking App',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
