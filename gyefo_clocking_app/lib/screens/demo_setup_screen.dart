import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/utils/demo_setup.dart';
import 'package:gyefo_clocking_app/utils/manual_account_creator.dart';

class DemoSetupScreen extends StatefulWidget {
  const DemoSetupScreen({super.key});

  @override
  State<DemoSetupScreen> createState() => _DemoSetupScreenState();
}

class _DemoSetupScreenState extends State<DemoSetupScreen> {
  bool _isLoading = false;
  String _status = '';
  bool _accountsExist = false;

  @override
  void initState() {
    super.initState();
    _checkExistingAccounts();
  }

  Future<void> _checkExistingAccounts() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking existing demo accounts...';
    });

    try {
      bool exist = await DemoSetup.demoAccountsExist();
      setState(() {
        _accountsExist = exist;
        _status =
            exist ? 'Demo accounts already exist' : 'No demo accounts found';
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking accounts: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _createDemoAccounts() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating demo accounts...';
    });

    try {
      await DemoSetup.createDemoAccounts();
      setState(() {
        _status =
            'Demo accounts created successfully!\n\nManager: manager@test.com\nPassword: password123\n\nWorker: worker@test.com\nPassword: password123';
        _accountsExist = true;
      });
    } catch (e) {
      setState(() {
        _status = 'Error creating demo accounts: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Demo setup is only available in debug mode',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Demo Setup'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, color: Colors.blue[600], size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Demo Account Setup',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This will create test accounts for the Gyefo Clocking App:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📧 Manager Account:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Email: manager@test.com'),
                          Text('Password: password123'),
                          SizedBox(height: 8),
                          Text(
                            '👷 Worker Account:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Email: worker@test.com'),
                          Text('Password: password123'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _accountsExist ? Icons.check_circle : Icons.info,
                          color: _accountsExist ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        _status.isEmpty
                            ? 'Ready to create demo accounts'
                            : _status,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createDemoAccounts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  _isLoading
                      ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Creating Accounts...'),
                        ],
                      )
                      : const Text(
                        'Create Demo Accounts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : _checkExistingAccounts,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[600],
                side: BorderSide(color: Colors.blue[600]!),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Check Existing Accounts',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                ManualAccountCreator.printSetupInstructions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Manual setup instructions printed to console',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(Icons.help_outline),
              label: Text('Manual Setup Instructions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green[600],
                side: BorderSide(color: Colors.green[600]!),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Only available in debug mode for security',
                      style: TextStyle(fontSize: 12),
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
}
