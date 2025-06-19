import 'package:flutter/foundation.dart';

/// Secure environment configuration manager
/// This replaces hardcoded API keys with environment variables
class EnvConfig {
  // Firebase Configuration
  static String get firebaseApiKeyWeb => _getEnvVar('FIREBASE_API_KEY_WEB');
  static String get firebaseApiKeyAndroid =>
      _getEnvVar('FIREBASE_API_KEY_ANDROID');
  static String get firebaseApiKeyIos => _getEnvVar('FIREBASE_API_KEY_IOS');
  static String get firebaseAppIdWeb => _getEnvVar('FIREBASE_APP_ID_WEB');
  static String get firebaseAppIdAndroid =>
      _getEnvVar('FIREBASE_APP_ID_ANDROID');
  static String get firebaseAppIdIos => _getEnvVar('FIREBASE_APP_ID_IOS');
  static String get firebaseMessagingSenderId =>
      _getEnvVar('FIREBASE_MESSAGING_SENDER_ID');
  static String get firebaseProjectId => _getEnvVar('FIREBASE_PROJECT_ID');
  static String get firebaseStorageBucket =>
      _getEnvVar('FIREBASE_STORAGE_BUCKET');
  static String get firebaseAuthDomain => _getEnvVar('FIREBASE_AUTH_DOMAIN');

  // Other API Keys (add as needed)
  static String get googleMapsApiKey =>
      _getEnvVar('GOOGLE_MAPS_API_KEY', fallback: '');
  static String get stripePublishableKey =>
      _getEnvVar('STRIPE_PUBLISHABLE_KEY', fallback: '');

  // Database Configuration
  static String get databaseUrl => _getEnvVar('DATABASE_URL', fallback: '');

  // Third-party Service Keys
  static String get pushNotificationKey =>
      _getEnvVar('PUSH_NOTIFICATION_KEY', fallback: '');

  /// Get environment variable with optional fallback
  static String _getEnvVar(String key, {String fallback = ''}) {
    // In production, these should come from environment variables
    // For now, we'll use const values that can be replaced during build
    const envVars = <String, String>{
      // Firebase Web
      'FIREBASE_API_KEY_WEB': String.fromEnvironment(
        'FIREBASE_API_KEY_WEB',
        defaultValue: '',
      ),
      'FIREBASE_APP_ID_WEB': String.fromEnvironment(
        'FIREBASE_APP_ID_WEB',
        defaultValue: '',
      ),

      // Firebase Android
      'FIREBASE_API_KEY_ANDROID': String.fromEnvironment(
        'FIREBASE_API_KEY_ANDROID',
        defaultValue: '',
      ),
      'FIREBASE_APP_ID_ANDROID': String.fromEnvironment(
        'FIREBASE_APP_ID_ANDROID',
        defaultValue: '',
      ),

      // Firebase iOS
      'FIREBASE_API_KEY_IOS': String.fromEnvironment(
        'FIREBASE_API_KEY_IOS',
        defaultValue: '',
      ),
      'FIREBASE_APP_ID_IOS': String.fromEnvironment(
        'FIREBASE_APP_ID_IOS',
        defaultValue: '',
      ),

      // Firebase Common
      'FIREBASE_MESSAGING_SENDER_ID': String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '',
      ),
      'FIREBASE_PROJECT_ID': String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: '',
      ),
      'FIREBASE_STORAGE_BUCKET': String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
        defaultValue: '',
      ),
      'FIREBASE_AUTH_DOMAIN': String.fromEnvironment(
        'FIREBASE_AUTH_DOMAIN',
        defaultValue: '',
      ),

      // Other APIs
      'GOOGLE_MAPS_API_KEY': String.fromEnvironment(
        'GOOGLE_MAPS_API_KEY',
        defaultValue: '',
      ),
      'STRIPE_PUBLISHABLE_KEY': String.fromEnvironment(
        'STRIPE_PUBLISHABLE_KEY',
        defaultValue: '',
      ),
      'DATABASE_URL': String.fromEnvironment('DATABASE_URL', defaultValue: ''),
      'PUSH_NOTIFICATION_KEY': String.fromEnvironment(
        'PUSH_NOTIFICATION_KEY',
        defaultValue: '',
      ),
    };

    final value = envVars[key] ?? fallback;

    // Validate critical keys in debug mode
    if (kDebugMode && value.isEmpty && _isCriticalKey(key)) {
      debugPrint('WARNING: Missing critical environment variable: $key');
    }

    return value;
  }

  /// Check if a key is critical for app functionality
  static bool _isCriticalKey(String key) {
    const criticalKeys = [
      'FIREBASE_API_KEY_WEB',
      'FIREBASE_API_KEY_ANDROID',
      'FIREBASE_API_KEY_IOS',
      'FIREBASE_PROJECT_ID',
    ];
    return criticalKeys.contains(key);
  }

  /// Validate all required environment variables are present
  static bool validateConfig() {
    final missingKeys = <String>[];

    // Check critical Firebase keys
    if (firebaseProjectId.isEmpty) missingKeys.add('FIREBASE_PROJECT_ID');
    if (firebaseApiKeyWeb.isEmpty) missingKeys.add('FIREBASE_API_KEY_WEB');
    if (firebaseApiKeyAndroid.isEmpty)
      missingKeys.add('FIREBASE_API_KEY_ANDROID');
    if (firebaseApiKeyIos.isEmpty) missingKeys.add('FIREBASE_API_KEY_IOS');

    if (missingKeys.isNotEmpty) {
      debugPrint(
        'Missing critical environment variables: ${missingKeys.join(', ')}',
      );
      return false;
    }

    return true;
  }

  /// Get current environment (development, staging, production)
  static String get environment =>
      const String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

  /// Check if running in production
  static bool get isProduction => environment == 'production';

  /// Check if running in development
  static bool get isDevelopment => environment == 'development';

  /// Check if running in staging
  static bool get isStaging => environment == 'staging';
}
