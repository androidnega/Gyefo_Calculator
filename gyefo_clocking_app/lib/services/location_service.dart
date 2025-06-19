import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'dart:math';

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

      AppLogger.info(
        'Current position: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      AppLogger.error('Error getting current position: $e');
      return null;
    }
  }

  /// Check if current position is within the allowed work zone
  static Future<LocationValidationResult> validateWorkLocation(
    String userId,
  ) async {
    try {
      // Get current position
      Position? currentPosition = await getCurrentPosition();
      if (currentPosition == null) {
        return LocationValidationResult(
          isValid: false,
          message:
              'Unable to get your current location. Please check GPS and permissions.',
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

      double allowedRadius =
          workLocation['radiusMeters'] ?? _defaultRadiusMeters;
      bool isWithinZone = distanceInMeters <= allowedRadius;

      return LocationValidationResult(
        isValid: isWithinZone,
        message:
            isWithinZone
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
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
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
          DocumentSnapshot companyDoc =
              await FirebaseFirestore.instance
                  .collection('companies')
                  .doc(companyId)
                  .get();

          if (companyDoc.exists) {
            Map<String, dynamic> companyData =
                companyDoc.data() as Map<String, dynamic>;
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
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'workLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters,
          'updatedAt': Timestamp.now(),
        },
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
            },
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

  /// Calculate distance using Haversine formula (alternative to Geolocator)
  /// This method provides more control over the calculation
  static double calculateDistanceHaversine(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double earthRadius = 6371000; // Earth radius in meters

    double dLat = _degToRad(endLat - startLat);
    double dLng = _degToRad(endLng - startLng);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(startLat)) *
            cos(_degToRad(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Convert degrees to radians
  static double _degToRad(double deg) => deg * (pi / 180);

  /// Validate location against default zone from Firestore
  static Future<ZoneValidationResult> validateZoneLocation() async {
    try {
      // Get current position
      Position? currentPosition = await getCurrentPosition();
      if (currentPosition == null) {
        return ZoneValidationResult(
          isWithinZone: false,
          message:
              'Unable to get your current location. Please check GPS and permissions.',
          currentPosition: null,
          zoneData: null,
          distance: null,
        );
      }

      // Get zone configuration from Firestore
      DocumentSnapshot zoneDoc =
          await FirebaseFirestore.instance
              .collection('zones')
              .doc('defaultZone')
              .get();

      if (!zoneDoc.exists) {
        return ZoneValidationResult(
          isWithinZone: true, // Allow if no zone is configured
          message: 'No work zone configured. Location validation bypassed.',
          currentPosition: currentPosition,
          zoneData: null,
          distance: null,
        );
      }

      Map<String, dynamic> zoneData = zoneDoc.data() as Map<String, dynamic>;

      // Check if zone is active
      if (zoneData['isActive'] == false) {
        return ZoneValidationResult(
          isWithinZone: true,
          message: 'Work zone validation is currently disabled.',
          currentPosition: currentPosition,
          zoneData: zoneData,
          distance: null,
        );
      }

      double zoneLat = zoneData['lat']?.toDouble() ?? 0.0;
      double zoneLng = zoneData['lng']?.toDouble() ?? 0.0;
      double allowedRadius =
          zoneData['radius']?.toDouble() ??
          300.0; // Calculate distance using Geolocator (more tested and reliable)
      double distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        zoneLat,
        zoneLng,
      );

      bool isWithinZone = distance <= allowedRadius;

      String zoneName = zoneData['name'] ?? 'Work Zone';

      return ZoneValidationResult(
        isWithinZone: isWithinZone,
        message:
            isWithinZone
                ? 'Location validated within $zoneName'
                : 'You are ${distance.round()}m away from $zoneName. Maximum allowed distance: ${allowedRadius.round()}m',
        currentPosition: currentPosition,
        zoneData: zoneData,
        distance: distance,
      );
    } catch (e) {
      AppLogger.error('Error validating zone location: $e');
      return ZoneValidationResult(
        isWithinZone: false,
        message: 'Error validating location: $e',
        currentPosition: null,
        zoneData: null,
        distance: null,
      );
    }
  }

  /// Get zone data from Firestore
  static Future<Map<String, dynamic>?> getZoneData() async {
    try {
      DocumentSnapshot zoneDoc =
          await FirebaseFirestore.instance
              .collection('zones')
              .doc('defaultZone')
              .get();

      if (zoneDoc.exists) {
        return zoneDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting zone data: $e');
      return null;
    }
  }

  /// Update zone configuration
  static Future<bool> updateZoneConfiguration({
    required double latitude,
    required double longitude,
    required double radius,
    String? name,
    String? address,
    bool? isActive,
  }) async {
    try {
      Map<String, dynamic> zoneData = {
        'lat': latitude,
        'lng': longitude,
        'radius': radius,
        'updatedAt': Timestamp.now(),
      };

      if (name != null) zoneData['name'] = name;
      if (address != null) zoneData['address'] = address;
      if (isActive != null) zoneData['isActive'] = isActive;

      await FirebaseFirestore.instance
          .collection('zones')
          .doc('defaultZone')
          .set(zoneData, SetOptions(merge: true));

      AppLogger.info('Zone configuration updated successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error updating zone configuration: $e');
      return false;
    }
  }

  /// Get the current location settings for a company
  static Future<Map<String, dynamic>?> getLocationSettings({String? companyId}) async {
    try {
      final effectiveCompanyId = companyId ?? await _getCompanyId();
      if (effectiveCompanyId == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(effectiveCompanyId)
          .collection('settings')
          .doc('location')
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      AppLogger.error('Error getting location settings: $e');
      return null;
    }
  }

  /// Update location settings for a company
  static Future<bool> updateLocationSettings({
    required double officeLat,
    required double officeLng,
    required double allowedRadius,
    String? companyId,
  }) async {
    try {
      final effectiveCompanyId = companyId ?? await _getCompanyId();
      if (effectiveCompanyId == null) return false;

      final settingsData = {
        'officeLat': officeLat,
        'officeLng': officeLng,
        'allowedRadius': allowedRadius,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'manager',
      };

      // Update the company's location settings
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(effectiveCompanyId)
          .collection('settings')
          .doc('location')
          .set(settingsData, SetOptions(merge: true));

      // Also update the legacy zones collection for backward compatibility
      await FirebaseFirestore.instance
          .collection('zones')
          .doc('default_zone')
          .set({
            'name': 'Office Location',
            'latitude': officeLat,
            'longitude': officeLng,
            'radius': allowedRadius,
            'isActive': true,
            'companyId': effectiveCompanyId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      return true;
    } catch (e) {
      AppLogger.error('Error updating location settings: $e');
      return false;
    }
  }

  /// Get the current user's company ID
  static Future<String?> _getCompanyId() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('manager_user_id') // This should be dynamic based on current user
          .get();

      return userDoc.data()?['companyId'] ?? 'default_company';
    } catch (e) {
      AppLogger.error('Error getting company ID: $e');
      return 'default_company';
    }
  }

  /// Stream location settings changes
  static Stream<Map<String, dynamic>?> streamLocationSettings({String? companyId}) {
    return Stream.fromFuture(_getCompanyId()).asyncExpand((effectiveCompanyId) {
      final targetCompanyId = companyId ?? effectiveCompanyId ?? 'default_company';
      
      return FirebaseFirestore.instance
          .collection('companies')
          .doc(targetCompanyId)
          .collection('settings')
          .doc('location')
          .snapshots()
          .map((doc) => doc.exists ? doc.data() : null);
    });
  }

  /// Validate location coordinates
  static bool isValidLocation(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
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

/// Result class for zone-based location validation
class ZoneValidationResult {
  final bool isWithinZone;
  final String message;
  final Position? currentPosition;
  final Map<String, dynamic>? zoneData;
  final double? distance;

  ZoneValidationResult({
    required this.isWithinZone,
    required this.message,
    this.currentPosition,
    this.zoneData,
    this.distance,
  });

  /// Get formatted distance string
  String get formattedDistance {
    if (distance == null) return 'N/A';
    return LocationService.formatDistance(distance!);
  }

  /// Check if location data is available
  bool get hasLocationData => currentPosition != null;

  /// Get zone name
  String get zoneName => zoneData?['name'] ?? 'Work Zone';

  /// Get zone radius
  double get zoneRadius => zoneData?['radius']?.toDouble() ?? 300.0;

  /// Get clock-in data for Firestore with zone validation
  Map<String, dynamic>? get clockInData {
    if (currentPosition == null) return null;

    return {
      'latitude': currentPosition!.latitude,
      'longitude': currentPosition!.longitude,
      'accuracy': currentPosition!.accuracy,
      'timestamp': Timestamp.now(),
      'isWithinZone': isWithinZone,
      'distanceFromZone': distance,
      'zoneName': zoneName,
      'zoneRadius': zoneRadius,
      'validationMessage': message,
    };
  }
}
