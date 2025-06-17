import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:developer' as developer;
import 'firebase_options.dart';

/// Script to set up the default work zone in Firestore
/// Run this once to create the zone configuration
Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;

  // Default zone configuration
  // You can update these coordinates to match your actual office/work location
  final zoneData = {
    'lat': 4.912345, // Replace with actual latitude
    'lng': -1.756789, // Replace with actual longitude
    'radius': 300, // 300 meters radius around the location
    'name': 'Main Office',
    'address': 'Your Office Address',
    'createdAt': Timestamp.now(),
    'isActive': true,
  };

  try {
    await firestore.collection('zones').doc('defaultZone').set(zoneData);

    developer.log('✅ Default zone created successfully!');
    developer.log('Zone details:');
    developer.log('  Latitude: ${zoneData['lat']}');
    developer.log('  Longitude: ${zoneData['lng']}');
    developer.log('  Radius: ${zoneData['radius']} meters');
    developer.log('  Name: ${zoneData['name']}');
  } catch (e) {
    developer.log('❌ Error creating zone: $e');
  }
}
