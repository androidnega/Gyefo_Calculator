import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';

/// Web-specific service for loading external APIs
class WebApiService {
  static bool _googleMapsLoaded = false;
  static bool _googleMapsLoading = false;

  /// Load Google Maps API dynamically for web platform
  static Future<void> loadGoogleMapsApi() async {
    if (!kIsWeb) {
      debugPrint('WebApiService: Not running on web platform');
      return;
    }

    if (_googleMapsLoaded) {
      debugPrint('WebApiService: Google Maps API already loaded');
      return;
    }

    if (_googleMapsLoading) {
      debugPrint('WebApiService: Google Maps API already loading');
      return;
    }

    _googleMapsLoading = true;

    try {
      final apiKey = EnvConfig.googleMapsApiKey;
      if (apiKey.isEmpty) {
        throw Exception('Google Maps API key not found in environment config');
      }

      // Check if script element exists
      final existingScript = html.document.getElementById('google-maps-api');
      if (existingScript != null) {
        // Update the src if it's empty
        final scriptElement = existingScript as html.ScriptElement;
        if (scriptElement.src.isEmpty) {
          scriptElement.src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey';
        }
      } else {
        // Create new script element
        final script = html.ScriptElement()
          ..id = 'google-maps-api'
          ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
          ..async = true
          ..defer = true;

        html.document.head!.children.add(script);
      }

      _googleMapsLoaded = true;
      debugPrint('WebApiService: Google Maps API loaded successfully');
    } catch (e) {
      debugPrint('WebApiService: Failed to load Google Maps API: $e');
      rethrow;
    } finally {
      _googleMapsLoading = false;
    }
  }

  /// Initialize Firebase configuration for web
  static Map<String, dynamic> getFirebaseWebConfig() {
    return {
      'apiKey': EnvConfig.firebaseApiKeyWeb,
      'authDomain': EnvConfig.firebaseAuthDomain,
      'projectId': EnvConfig.firebaseProjectId,
      'storageBucket': EnvConfig.firebaseStorageBucket,
      'messagingSenderId': EnvConfig.firebaseMessagingSenderId,
      'appId': EnvConfig.firebaseAppIdWeb,
    };
  }

  /// Validate web configuration
  static bool validateWebConfig() {
    final config = getFirebaseWebConfig();
    final missingKeys = <String>[];

    for (final entry in config.entries) {
      if (entry.value == null || entry.value.toString().isEmpty) {
        missingKeys.add(entry.key);
      }
    }

    if (missingKeys.isNotEmpty) {
      debugPrint('WebApiService: Missing Firebase web config: ${missingKeys.join(', ')}');
      return false;
    }

    return true;
  }
}
