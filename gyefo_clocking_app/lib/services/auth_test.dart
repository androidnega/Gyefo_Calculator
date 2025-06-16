// ⚠️ TEMPORARY FILE - Remove after creating test accounts

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

Future<void> createTestAccounts() async {
  try {
    if (kDebugMode) {
      print('🔧 Creating test accounts...');
    }

    // 1. Create Manager Account
    if (kDebugMode) {
      print('Creating manager account...');
    }

    final managerCred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: 'manager@test.com',
          password: '123456',
        );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(managerCred.user!.uid)
        .set({
          'uid': managerCred.user!.uid,
          'email': 'manager@test.com',
          'name': 'Manager One',
          'role': 'manager',
        });

    if (kDebugMode) {
      print('✅ Manager account created: manager@test.com');
    }

    // 2. Sign out temporarily
    await FirebaseAuth.instance.signOut();

    // 3. Create Worker Account
    if (kDebugMode) {
      print('Creating worker account...');
    }

    final workerCred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: 'worker@test.com',
          password: '123456',
        );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(workerCred.user!.uid)
        .set({
          'uid': workerCred.user!.uid,
          'email': 'worker@test.com',
          'name': 'Worker One',
          'role': 'worker',
        });

    if (kDebugMode) {
      print('✅ Worker account created: worker@test.com');
    }

    // 4. Sign out again to return to login screen
    await FirebaseAuth.instance.signOut();

    if (kDebugMode) {
      print('🎉 Test accounts created successfully!');
      print('📝 Manager: manager@test.com / 123456');
      print('📝 Worker: worker@test.com / 123456');
      print(
        '⚠️ Remember to remove createTestAccounts() from main.dart after first run!',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error creating test accounts: ${e.toString()}');
      // Check if accounts already exist
      if (e.toString().contains('email-already-in-use')) {
        print('✅ Test accounts may already exist. Try logging in with:');
        print('📝 Manager: manager@test.com / 123456');
        print('📝 Worker: worker@test.com / 123456');
      }
    }
  }
}
