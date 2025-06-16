import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Import foundation for kDebugMode

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      // Consider returning a more specific error or using a result type
      return null;
    }
  }

  static Future<void> createUserDocument(
    String uid,
    String name,
    String role,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'role': role,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error creating user document: ${e.toString()}');
      }
      // Consider throwing an error to be handled by the caller
    }
  }
}
