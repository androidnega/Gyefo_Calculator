import 'package:shared_preferences/shared_preferences.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

/// Service for managing user preferences and credentials
class PreferencesService {
  static const String _keyRememberCredentials = 'remember_credentials';
  static const String _keyStoredEmail = 'stored_email';
  static const String _keyStoredPassword = 'stored_password';

  /// Save user credentials for auto-login
  static Future<void> saveCredentials({
    required String email,
    required String password,
    required bool rememberCredentials,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_keyRememberCredentials, rememberCredentials);

      if (rememberCredentials) {
        await prefs.setString(_keyStoredEmail, email);
        await prefs.setString(_keyStoredPassword, password);
        AppLogger.info('Credentials saved successfully');
      } else {
        // Clear stored credentials if user unchecks remember me
        await clearCredentials();
      }
    } catch (e) {
      AppLogger.error('Error saving credentials: $e');
    }
  }

  /// Load saved credentials
  static Future<Map<String, String?>> loadCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rememberCredentials =
          prefs.getBool(_keyRememberCredentials) ?? false;

      if (rememberCredentials) {
        final email = prefs.getString(_keyStoredEmail);
        final password = prefs.getString(_keyStoredPassword);

        return {'email': email, 'password': password};
      }

      return {'email': null, 'password': null};
    } catch (e) {
      AppLogger.error('Error loading credentials: $e');
      return {'email': null, 'password': null};
    }
  }

  /// Check if credentials should be remembered
  static Future<bool> shouldRememberCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRememberCredentials) ?? false;
    } catch (e) {
      AppLogger.error('Error checking remember credentials setting: $e');
      return false;
    }
  }

  /// Clear stored credentials
  static Future<void> clearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyStoredEmail);
      await prefs.remove(_keyStoredPassword);
      await prefs.setBool(_keyRememberCredentials, false);
      AppLogger.info('Credentials cleared successfully');
    } catch (e) {
      AppLogger.error('Error clearing credentials: $e');
    }
  }

  /// Save a general preference
  static Future<void> savePreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      }
    } catch (e) {
      AppLogger.error('Error saving preference $key: $e');
    }
  }

  /// Load a general preference
  static Future<T?> loadPreference<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (T == String) {
        return prefs.getString(key) as T?;
      } else if (T == int) {
        return prefs.getInt(key) as T?;
      } else if (T == double) {
        return prefs.getDouble(key) as T?;
      } else if (T == bool) {
        return prefs.getBool(key) as T?;
      } else if (T == List<String>) {
        return prefs.getStringList(key) as T?;
      }

      return null;
    } catch (e) {
      AppLogger.error('Error loading preference $key: $e');
      return null;
    }
  }
}
