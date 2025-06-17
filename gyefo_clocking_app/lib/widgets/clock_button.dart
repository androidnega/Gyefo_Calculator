import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/services/attendance_service.dart';
import 'package:gyefo_clocking_app/services/location_service.dart';
import 'package:gyefo_clocking_app/services/biometric_service.dart';
import 'package:gyefo_clocking_app/services/auth_service.dart';

class ClockButton extends StatefulWidget {
  final VoidCallback? onClockStatusChanged;

  const ClockButton({super.key, this.onClockStatusChanged});

  @override
  State<ClockButton> createState() => _ClockButtonState();
}

class _ClockButtonState extends State<ClockButton> {
  bool _isLoading = false;
  bool _isClockedIn = false;
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _checkClockStatus();
  }

  Future<void> _checkClockStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final hasClockedIn = await _attendanceService.hasClockedInToday(
          user.uid,
        );
        setState(() {
          _isClockedIn = hasClockedIn;
        });
      } catch (e) {
        _showErrorMessage('Error checking clock status: ${e.toString()}');
      }
    }
  }
  Future<void> _handleClockAction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorMessage('User not authenticated');
      return;
    }

    // Check if biometric authentication should be used
    final shouldUseBiometric = await BiometricService.shouldUseBiometricForClocking();
    if (shouldUseBiometric) {
      // Get worker name for personalized biometric prompt
      String? workerName;
      try {
        final worker = await AuthService().getWorkerById(user.uid);
        workerName = worker?.name;
      } catch (e) {
        // Continue without name if we can't get it
      }

      // Perform biometric authentication
      final authenticated = await BiometricService.authenticateForClocking(
        isClockIn: !_isClockedIn,
        workerName: workerName,
      );

      if (!authenticated) {
        _showErrorMessage('Biometric authentication failed or was cancelled');
        return;
      }
    }

    // Check if today is a holiday
    final isHoliday = await _checkIfHoliday();
    if (isHoliday) {
      _showErrorMessage('Cannot clock in/out: Today is a holiday.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate location before proceeding
      final locationResult = await LocationService.validateWorkLocation(
        user.uid,
      );

      if (!locationResult.isValid) {
        setState(() {
          _isLoading = false;
        });

        // Show location validation error with option to proceed anyway
        await _showLocationValidationDialog(locationResult);
        return;
      }
      if (_isClockedIn) {
        await _attendanceService.clockOut(
          user.uid,
          locationData: locationResult.locationData,
        );
        _showSuccessMessage('Clocked out successfully!');
        setState(() {
          _isClockedIn = false;
        });
        widget.onClockStatusChanged?.call();
      } else {
        await _attendanceService.clockIn(
          user.uid,
          locationData: locationResult.locationData,
        );
        _showSuccessMessage('Clocked in successfully!');
        setState(() {
          _isClockedIn = true;
        });
        widget.onClockStatusChanged?.call();
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Already clocked in today')) {
        errorMessage = 'You have already clocked in today.';
      } else if (errorMessage.contains('No active clock-in found for today')) {
        errorMessage = 'No active clock-in found. Please clock in first.';
      }
      _showErrorMessage(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkIfHoliday() async {
    try {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);

      final snapshot =
          await FirebaseFirestore.instance
              .collection('holidays')
              .where('date', isEqualTo: Timestamp.fromDate(normalizedToday))
              .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      // If there's an error checking holidays, allow clock-in to proceed
      return false;
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showLocationValidationDialog(
    LocationValidationResult result,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_off, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Location Verification'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message),
              const SizedBox(height: 16),
              if (result.distance != null) ...[
                Text(
                  'Distance from workplace: ${result.formattedDistance}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 8),
              ],
              const Text(
                'Would you like to proceed anyway? This will be flagged in the system.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proceed Anyway'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _proceedWithFlaggedLocation(result);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _proceedWithFlaggedLocation(
    LocationValidationResult result,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isClockedIn) {
        await _attendanceService.clockOut(
          user.uid,
          locationData: result.locationData,
        );
        _showSuccessMessage('Clocked out successfully! (Location flagged)');
        setState(() {
          _isClockedIn = false;
        });
        widget.onClockStatusChanged?.call();
      } else {
        await _attendanceService.clockIn(
          user.uid,
          locationData: result.locationData,
        );
        _showSuccessMessage('Clocked in successfully! (Location flagged)');
        setState(() {
          _isClockedIn = true;
        });
        widget.onClockStatusChanged?.call();
      }
    } catch (e) {
      _showErrorMessage('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isClockedIn ? Icons.logout : Icons.login,
              size: 48,
              color: _isClockedIn ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              _isClockedIn ? 'Clock Out' : 'Clock In',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _handleClockAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isClockedIn ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    _isClockedIn ? 'Clock Out' : 'Clock In',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              DateTime.now().toString().split('.')[0],
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
