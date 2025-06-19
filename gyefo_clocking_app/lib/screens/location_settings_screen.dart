import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  Map<String, dynamic>? _currentSettings;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    
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

      if (settingsDoc.exists) {
        _currentSettings = settingsDoc.data();
        _latController.text = _currentSettings?['officeLat']?.toString() ?? '';
        _lngController.text = _currentSettings?['officeLng']?.toString() ?? '';
        _radiusController.text = _currentSettings?['allowedRadius']?.toString() ?? '100';
      } else {
        // Set default values
        _radiusController.text = '100';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions permanently denied';
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location loaded successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_companyId == null) throw 'Company ID not found';

      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);
      final radius = double.parse(_radiusController.text);

      final settingsData = {
        'officeLat': lat,
        'officeLng': lng,
        'allowedRadius': radius,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      };

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .collection('settings')
          .doc('location')
          .set(settingsData, SetOptions(merge: true));

      // Also update the legacy zone collection for backward compatibility
      await FirebaseFirestore.instance
          .collection('zones')
          .doc('default_zone')
          .set({
            'name': 'Office Location',
            'latitude': lat,
            'longitude': lng,
            'radius': radius,
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location settings saved successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        title: const Text(
          'Location Settings',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Settings Card
                    _buildCurrentSettingsCard(),
                    const SizedBox(height: 24),

                    // Office Location Section
                    _buildSectionHeader('Office Location'),
                    const SizedBox(height: 16),
                    _buildLocationForm(),
                    const SizedBox(height: 24),

                    // Geo-fence Settings
                    _buildSectionHeader('Geo-fence Settings'),
                    const SizedBox(height: 16),
                    _buildRadiusForm(),
                    const SizedBox(height: 32),

                    // Save Button
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentSettingsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  'Current Geo-fence Rules',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentSettings != null) ...[
              _buildInfoRow('Office Latitude', _currentSettings!['officeLat']?.toString() ?? 'Not set'),
              _buildInfoRow('Office Longitude', _currentSettings!['officeLng']?.toString() ?? 'Not set'),
              _buildInfoRow('Allowed Radius', '${_currentSettings!['allowedRadius']?.toString() ?? '100'} meters'),
            ] else ...[
              const Text(
                'No location settings configured yet.',
                style: TextStyle(color: AppTheme.textLight),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildLocationForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g., 5.6037',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.my_location),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter latitude';
                }
                final lat = double.tryParse(value);
                if (lat == null || lat < -90 || lat > 90) {
                  return 'Please enter a valid latitude (-90 to 90)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g., -0.1870',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter longitude';
                }
                final lng = double.tryParse(value);
                if (lng == null || lng < -180 || lng > 180) {
                  return 'Please enter a valid longitude (-180 to 180)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Use Current Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _radiusController,
              decoration: const InputDecoration(
                labelText: 'Allowed Clock-in Radius (meters)',
                hintText: 'e.g., 100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.radio_button_unchecked),
                suffixText: 'meters',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter radius';
                }
                final radius = double.tryParse(value);
                if (radius == null || radius <= 0 || radius > 10000) {
                  return 'Please enter a valid radius (1-10000 meters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Workers must be within this radius of the office location to clock in/out.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Save Location Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
