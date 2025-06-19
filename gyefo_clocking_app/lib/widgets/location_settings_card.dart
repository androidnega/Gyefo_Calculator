import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../screens/location_settings_screen.dart';

class LocationSettingsCard extends StatefulWidget {
  const LocationSettingsCard({super.key});

  @override
  State<LocationSettingsCard> createState() => _LocationSettingsCardState();
}

class _LocationSettingsCardState extends State<LocationSettingsCard> {
  Map<String, dynamic>? _locationSettings;
  bool _isLoading = true;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadLocationSettings();
  }

  Future<void> _loadLocationSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user's company ID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      _companyId = userDoc.data()?['companyId'] ?? 'default_company';

      // Load location settings
      final settingsDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('settings')
          .doc('location')
          .get();

      if (mounted) {
        setState(() {
          _locationSettings = settingsDoc.exists ? settingsDoc.data() : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LocationSettingsScreen(),
            ),
          );
          if (result == true) {
            _loadLocationSettings(); // Refresh after settings update
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Location Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textLight,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Content
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_locationSettings == null)
                _buildNotConfiguredState()
              else
                _buildConfiguredState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotConfiguredState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Location settings not configured. Tap to set up geo-fence rules.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguredState() {
    return Column(
      children: [
        _buildInfoRow(
          'Office Location',
          '${_locationSettings!['officeLat']?.toStringAsFixed(4) ?? 'N/A'}, ${_locationSettings!['officeLng']?.toStringAsFixed(4) ?? 'N/A'}',
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Allowed Radius',
          '${_locationSettings!['allowedRadius']?.toString() ?? '100'} meters',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade600,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Geo-fence active - Workers can only clock in within the defined area',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textDark,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textLight,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
