import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

/// Handles creation and management of demo accounts for testing
class DemoSetup {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates demo accounts for testing
  static Future<void> createDemoAccounts() async {
    try {
      // Only allow in debug mode for security
      if (!kDebugMode) {
        AppLogger.warning(
          'Demo account creation is only available in debug mode',
        );
        return;
      }

      AppLogger.info('Starting demo account creation...');

      // Create Manager Account
      await _createManagerAccount();

      // Create Worker Account
      await _createWorkerAccount();

      AppLogger.success('Demo accounts created successfully!');
      AppLogger.info('You can now test the app with:');
      AppLogger.info('Manager: manager@test.com / password123');
      AppLogger.info('Worker: worker@test.com / password123');
    } catch (e) {
      AppLogger.error('Error creating demo accounts: $e');
    }
  }

  /// Creates the manager account and Firestore document
  static Future<void> _createManagerAccount() async {
    try {
      // Sign out any current user
      await _auth.signOut();

      // Create manager account
      UserCredential managerCredential = await _auth
          .createUserWithEmailAndPassword(
            email: 'manager@test.com',
            password: 'password123',
          );

      // Create manager document in Firestore
      UserModel manager = UserModel(
        uid: managerCredential.user!.uid,
        name: 'Demo Manager',
        role: 'manager',
        email: 'manager@test.com',
      );

      await _firestore
          .collection('users')
          .doc(managerCredential.user!.uid)
          .set(manager.toMap());

      AppLogger.success('Manager account created: manager@test.com');
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        AppLogger.info(
          'Manager account already exists, updating Firestore document...',
        );
        await _updateExistingManagerDocument();
      } else {
        AppLogger.error('Error creating manager account: $e');
        rethrow;
      }
    }
  }

  /// Creates the worker account and Firestore document
  static Future<void> _createWorkerAccount() async {
    try {
      // Sign out any current user
      await _auth.signOut();

      // Create worker account
      UserCredential workerCredential = await _auth
          .createUserWithEmailAndPassword(
            email: 'worker@test.com',
            password: 'password123',
          );

      // Create worker document in Firestore
      UserModel worker = UserModel(
        uid: workerCredential.user!.uid,
        name: 'Demo Worker',
        role: 'worker',
        email: 'worker@test.com',
      );

      await _firestore
          .collection('users')
          .doc(workerCredential.user!.uid)
          .set(worker.toMap());

      AppLogger.success('Worker account created: worker@test.com');
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        AppLogger.info(
          'Worker account already exists, updating Firestore document...',
        );
        await _updateExistingWorkerDocument();
      } else {
        AppLogger.error('Error creating worker account: $e');
        rethrow;
      }
    }
  }

  /// Updates the Firestore document for an existing manager account
  static Future<void> _updateExistingManagerDocument() async {
    try {
      // Sign in as manager to get UID
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: 'manager@test.com',
        password: 'password123',
      );

      UserModel manager = UserModel(
        uid: credential.user!.uid,
        name: 'Demo Manager',
        role: 'manager',
        email: 'manager@test.com',
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(manager.toMap(), SetOptions(merge: true));

      AppLogger.success('Manager Firestore document updated');
    } catch (e) {
      AppLogger.error('Error updating manager document: $e');
    }
  }

  /// Updates the Firestore document for an existing worker account
  static Future<void> _updateExistingWorkerDocument() async {
    try {
      // Sign in as worker to get UID
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: 'worker@test.com',
        password: 'password123',
      );

      UserModel worker = UserModel(
        uid: credential.user!.uid,
        name: 'Demo Worker',
        role: 'worker',
        email: 'worker@test.com',
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(worker.toMap(), SetOptions(merge: true));

      AppLogger.success('Worker Firestore document updated');
    } catch (e) {
      AppLogger.error('Error updating worker document: $e');
    }
  }

  /// Checks if demo accounts exist
  static Future<bool> demoAccountsExist() async {
    try {
      // Check if manager account exists
      await _auth.signInWithEmailAndPassword(
        email: 'manager@test.com',
        password: 'password123',
      );
      await _auth.signOut();

      // Check if worker account exists
      await _auth.signInWithEmailAndPassword(
        email: 'worker@test.com',
        password: 'password123',
      );
      await _auth.signOut();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clears all demo data (for testing purposes)
  static Future<void> clearDemoData() async {
    if (!kDebugMode) {
      AppLogger.warning('Demo data clearing is only available in debug mode');
      return;
    }

    try {
      AppLogger.warning('Demo data clearing would require admin privileges');
      AppLogger.warning(
        'Manually delete accounts from Firebase Console if needed',
      );
    } catch (e) {
      AppLogger.error('Error clearing demo data: $e');
    }
  }
}
