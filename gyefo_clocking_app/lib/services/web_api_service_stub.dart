/// Stub implementation for non-web platforms
class WebApiService {
  /// Load Google Maps API dynamically (stub for non-web platforms)
  static Future<void> loadGoogleMapsApi() async {
    // No-op for non-web platforms
  }

  /// Initialize Firebase configuration for web (stub for non-web platforms)
  static Map<String, dynamic> getFirebaseWebConfig() {
    return {};
  }

  /// Validate web configuration (stub for non-web platforms)
  static bool validateWebConfig() {
    return true; // Always valid for non-web platforms
  }
}
