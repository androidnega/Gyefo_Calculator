import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/services/biometric_service.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() =>
      _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _biometricInfo = {};

  @override
  void initState() {
    super.initState();
    _loadBiometricInfo();
  }

  Future<void> _loadBiometricInfo() async {
    try {
      final info = await BiometricService.getBiometricInfo();
      setState(() {
        _biometricInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading biometric info: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testBiometricAuthentication() async {
    try {
      final authenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'Test biometric authentication for the Gyefo Clocking App',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authenticated
                  ? 'Biometric authentication successful!'
                  : 'Biometric authentication failed or was cancelled',
            ),
            backgroundColor: authenticated ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error testing biometric authentication: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing biometric authentication: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biometric Settings')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBiometricStatusCard(),
                    const SizedBox(height: 16),
                    if (_biometricInfo['isAvailable'] == true) ...[
                      _buildBiometricDetailsCard(),
                      const SizedBox(height: 16),
                      _buildTestCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildSecurityInfoCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildBiometricStatusCard() {
    final isAvailable = _biometricInfo['isAvailable'] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAvailable ? Icons.verified_user : Icons.security,
                  color: isAvailable ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Biometric Authentication Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isAvailable
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isAvailable
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isAvailable ? 'Available' : 'Not Available',
                    style: TextStyle(
                      color: isAvailable ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isAvailable
                  ? 'Biometric authentication is available and will be used for secure clock in/out operations.'
                  : 'Biometric authentication is not available on this device. You will use standard authentication methods.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricDetailsCard() {
    final description = _biometricInfo['description'] ?? 'Unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fingerprint, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Available Biometrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.security, 'Types', description),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.device_hub,
              'Device Support',
              _biometricInfo['isDeviceSupported'] == true
                  ? 'Supported'
                  : 'Not Supported',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.check_circle,
              'Capability Check',
              _biometricInfo['canCheckBiometrics'] == true
                  ? 'Available'
                  : 'Not Available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  Widget _buildTestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Test Biometric Authentication',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Test your biometric authentication to ensure it works properly.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testBiometricAuthentication,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Test Biometric Authentication'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Security Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSecurityPoint(
              'Enhanced Security',
              'Biometric authentication provides an additional layer of security for your attendance records.',
            ),
            const SizedBox(height: 12),
            _buildSecurityPoint(
              'Privacy Protection',
              'Your biometric data is processed locally on your device and never transmitted or stored on our servers.',
            ),
            const SizedBox(height: 12),
            _buildSecurityPoint(
              'Fallback Options',
              'If biometric authentication fails, you can use your device\'s PIN, pattern, or password as a fallback.',
            ),
            const SizedBox(height: 12),
            _buildSecurityPoint(
              'Company Policy',
              'Biometric authentication requirements may vary based on your company\'s security policies.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityPoint(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.security, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
