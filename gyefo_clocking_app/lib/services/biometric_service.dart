import 'package:flutter/foundation.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

// Mock biometric types enum for demo purposes
enum MockBiometricType {
  face,
  fingerprint,
  iris,
  strong,
  weak,
}

class BiometricService {
  /// Check if biometric authentication is available on the device
  /// Note: This is a mock implementation. In production, install local_auth package
  static Future<bool> isBiometricAvailable() async {
    try {
      // Mock implementation - in production this would use local_auth package
      // For now, simulate availability on non-web platforms
      if (kIsWeb) return false;
      
      // Simulate that biometrics are available on mobile platforms
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      AppLogger.error('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<MockBiometricType>> getAvailableBiometrics() async {
    try {
      // Mock implementation - return fingerprint for demo
      await Future.delayed(const Duration(milliseconds: 100));
      return [MockBiometricType.fingerprint];
    } catch (e) {
      AppLogger.error('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate using biometrics
  static Future<bool> authenticateWithBiometrics({
    required String reason,
    bool fallbackToDeviceCredentials = true,
  }) async {
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        AppLogger.warning('Biometric authentication not available');
        return false;
      }

      // Mock implementation - simulate user authentication
      AppLogger.info('Mock biometric authentication requested: $reason');
      
      // Simulate authentication delay
      await Future.delayed(const Duration(seconds: 1));
        // For demo purposes, always return true
      // In production, this would use the local_auth package
      const bool didAuthenticate = true;

      AppLogger.success('Mock biometric authentication successful');

      return didAuthenticate;
    } catch (e) {
      AppLogger.error('Error during biometric authentication: $e');
      return false;
    }
  }

  /// Stop authentication (if in progress)
  static Future<bool> stopAuthentication() async {
    try {
      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      AppLogger.error('Error stopping authentication: $e');
      return false;
    }
  }

  /// Get a user-friendly description of available biometric types
  static String getBiometricDescription(List<MockBiometricType> biometrics) {
    if (biometrics.isEmpty) return 'No biometric authentication available';

    final List<String> descriptions = [];
    
    if (biometrics.contains(MockBiometricType.face)) {
      descriptions.add('Face ID');
    }
    if (biometrics.contains(MockBiometricType.fingerprint)) {
      descriptions.add('Fingerprint');
    }
    if (biometrics.contains(MockBiometricType.iris)) {
      descriptions.add('Iris');
    }
    if (biometrics.contains(MockBiometricType.strong)) {
      descriptions.add('Strong biometrics');
    }
    if (biometrics.contains(MockBiometricType.weak)) {
      descriptions.add('Weak biometrics');
    }

    if (descriptions.isEmpty) return 'Biometric authentication';
    if (descriptions.length == 1) return descriptions.first;
    if (descriptions.length == 2) return '${descriptions[0]} or ${descriptions[1]}';
    
    return '${descriptions.sublist(0, descriptions.length - 1).join(', ')}, or ${descriptions.last}';
  }

  /// Check if user should use biometric authentication for clocking
  /// This could be based on app settings, company policy, etc.
  static Future<bool> shouldUseBiometricForClocking() async {
    // For now, return true if biometrics are available
    // In a real app, this would check user preferences and company policies
    return await isBiometricAvailable();
  }

  /// Authenticate for clock in/out with appropriate messaging
  static Future<bool> authenticateForClocking({
    required bool isClockIn,
    String? workerName,
  }) async {
    final String action = isClockIn ? 'clock in' : 'clock out';
    final String name = workerName ?? 'worker';
    
    final String reason = 'Verify your identity to $action as $name';
    
    return await authenticateWithBiometrics(
      reason: reason,
      fallbackToDeviceCredentials: true,
    );
  }

  /// Show biometric setup information
  static Future<Map<String, dynamic>> getBiometricInfo() async {
    final bool isAvailable = await isBiometricAvailable();
    final List<MockBiometricType> availableBiometrics = await getAvailableBiometrics();
    
    return {
      'isAvailable': isAvailable,
      'availableBiometrics': availableBiometrics,
      'description': getBiometricDescription(availableBiometrics),
      'isDeviceSupported': !kIsWeb, // Mock device support
      'canCheckBiometrics': !kIsWeb, // Mock biometric check capability
    };
  }
}
