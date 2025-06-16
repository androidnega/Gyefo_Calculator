import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class LocationService {
  static const double _defaultRadiusMeters = 100.0; // Default geo-fence radius

  /// Check if location services are enabled and permissions are granted
  static Future<bool> checkLocationPermissions() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services are disabled');
        return false;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.warning('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('Location permissions are permanently denied');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('Error checking location permissions: $e');
      return false;
    }
  }

  /// Get current position with high accuracy
  static Future<Position?> getCurrentPosition() async {
    try {
      if (!await checkLocationPermissions()) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      AppLogger.info('Current position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      AppLogger.error('Error getting current position: $e');
      return null;
    }
  }

  /// Check if current position is within the allowed work zone
  static Future<LocationValidationResult> validateWorkLocation(String userId) async {
    try {
      // Get current position
      Position? currentPosition = await getCurrentPosition();
      if (currentPosition == null) {
        return LocationValidationResult(
          isValid: false,
          message: 'Unable to get your current location. Please check GPS and permissions.',
          currentPosition: null,
          workLocation: null,
          distance: null,
        );
      }

      // Get work location for user
      Map<String, dynamic>? workLocation = await getWorkLocation(userId);
      if (workLocation == null) {
        // If no specific work location is set, allow clock-in (optional enforcement)
        return LocationValidationResult(
          isValid: true,
          message: 'Location validation successful',
          currentPosition: currentPosition,
          workLocation: null,
          distance: null,
        );
      }

      // Calculate distance
      double distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        workLocation['latitude'],
        workLocation['longitude'],
      );

      double allowedRadius = workLocation['radiusMeters'] ?? _defaultRadiusMeters;
      bool isWithinZone = distanceInMeters <= allowedRadius;

      return LocationValidationResult(
        isValid: isWithinZone,
        message: isWithinZone
            ? 'Location validated successfully'
            : 'You are ${distanceInMeters.round()}m away from your workplace. Allowed distance: ${allowedRadius.round()}m',
        currentPosition: currentPosition,
        workLocation: workLocation,
        distance: distanceInMeters,
      );
    } catch (e) {
      AppLogger.error('Error validating work location: $e');
      return LocationValidationResult(
        isValid: false,
        message: 'Error validating location: $e',
        currentPosition: null,
        workLocation: null,
        distance: null,
      );
    }
  }

  /// Get work location for a specific user
  static Future<Map<String, dynamic>?> getWorkLocation(String userId) async {
    try {
      // First check if user has a specific work location
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        if (userData['workLocation'] != null) {
          return userData['workLocation'];
        }

        // If no user-specific location, check company default location
        String? companyId = userData['companyId'];
        if (companyId != null) {
          DocumentSnapshot companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .get();

          if (companyDoc.exists) {
            Map<String, dynamic> companyData = companyDoc.data() as Map<String, dynamic>;
            return companyData['workLocation'];
          }
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('Error getting work location: $e');
      return null;
    }
  }

  /// Set work location for a user
  static Future<bool> setUserWorkLocation(
    String userId,
    double latitude,
    double longitude,
    double radiusMeters,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'workLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters,
          'updatedAt': Timestamp.now(),
        }
      });

      AppLogger.info('Work location set for user $userId');
      return true;
    } catch (e) {
      AppLogger.error('Error setting work location: $e');
      return false;
    }
  }

  /// Set company-wide work location
  static Future<bool> setCompanyWorkLocation(
    String companyId,
    double latitude,
    double longitude,
    double radiusMeters,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .set({
        'workLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters,
          'updatedAt': Timestamp.now(),
        }
      }, SetOptions(merge: true));

      AppLogger.info('Company work location set for $companyId');
      return true;
    } catch (e) {
      AppLogger.error('Error setting company work location: $e');
      return false;
    }
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }
}

/// Result class for location validation
class LocationValidationResult {
  final bool isValid;
  final String message;
  final Position? currentPosition;
  final Map<String, dynamic>? workLocation;
  final double? distance;

  LocationValidationResult({
    required this.isValid,
    required this.message,
    this.currentPosition,
    this.workLocation,
    this.distance,
  });

  /// Get formatted distance string
  String get formattedDistance {
    if (distance == null) return 'N/A';
    return LocationService.formatDistance(distance!);
  }

  /// Check if location data is available
  bool get hasLocationData => currentPosition != null;

  /// Get location data for saving to Firestore
  Map<String, dynamic>? get locationData {
    if (currentPosition == null) return null;
    
    return {
      'latitude': currentPosition!.latitude,
      'longitude': currentPosition!.longitude,
      'accuracy': currentPosition!.accuracy,
      'timestamp': Timestamp.now(),
      'isWithinWorkZone': isValid && workLocation != null,
      'distanceFromWork': distance,
    };
  }
}
