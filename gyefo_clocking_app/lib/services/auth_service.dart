import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Import foundation for kDebugMode
import 'package:flutter/material.dart'; // Required for Dialogs
import 'package:gyefo_clocking_app/services/firestore_service.dart'; // Import FirestoreService

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper function to prompt for manager's password
  // This would typically be implemented in the UI layer and passed as a callback
  // or the BuildContext would be passed to this service method.
  // For simplicity here, we define it, but it will need UI integration.
  Future<String?> promptManagerPassword(BuildContext context) async {
    String? password;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController passwordController =
            TextEditingController();
        return AlertDialog(
          title: const Text('Re-authenticate Manager'),
          content: TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Enter your password'),
            obscureText: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                password = passwordController.text;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    return password;
  }

  Future<User?> createWorkerAccount(
    BuildContext context,
    String workerEmail,
    String workerPassword,
    String workerName,
  ) async {
    User? currentManager = _auth.currentUser;
    if (currentManager == null) {
      if (kDebugMode) {
        print("Error: No manager is currently signed in.");
      }
      return null; // Or throw an exception
    }

    String? managerEmail = currentManager.email;
    if (managerEmail == null) {
      if (kDebugMode) {
        print("Error: Manager email is null.");
      }
      // This case should ideally not happen if manager is properly authenticated
      return null;
    }

    // 1. Prompt manager for their password
    String? managerPassword = await promptManagerPassword(context);
    if (managerPassword == null || managerPassword.isEmpty) {
      if (kDebugMode) {
        print("Manager password not provided or dialog cancelled.");
      }
      return null; // Password prompt was cancelled or password was empty
    }

    try {
      // 2. Temporarily sign out manager (not strictly necessary if re-authenticating,
      // but good for isolating the worker creation process with a fresh auth state for createUser)
      // However, Firebase Admin SDK is better for this.
      // For client-side, we'll re-authenticate the manager first to ensure they are who they say they are.

      AuthCredential credential = EmailAuthProvider.credential(
        email: managerEmail,
        password: managerPassword,
      );
      await currentManager.reauthenticateWithCredential(credential);
      if (kDebugMode) {
        print("Manager re-authenticated successfully.");
      }

      // 3. Create the new worker account
      // To create a new user, we can't be signed in as the manager with the main _auth instance
      // if we use createUserWithEmailAndPassword.
      // A common approach is to use a secondary Firebase app instance or a Callable Function.
      // Given the current constraints, we will sign out the manager, create worker, then sign manager back in.
      // This is not ideal due to potential UI flicker and complexity.
      // A Firebase Function would be the recommended way to handle this securely and smoothly.

      // Storing manager's credentials to sign back in
      // Note: Storing password directly is a security risk.
      // This is a simplified example. In a real app, avoid this.
      // The re-authentication step above confirms the manager's password.

      await _auth.signOut(); // Sign out manager

      UserCredential? workerCredential;
      try {
        workerCredential = await _auth.createUserWithEmailAndPassword(
          email: workerEmail,
          password: workerPassword,
        );
      } catch (e) {
        if (kDebugMode) {
          print("Error creating worker account: ${e.toString()}");
        }
        // Attempt to sign the manager back in if worker creation failed
        await _auth.signInWithEmailAndPassword(
          email: managerEmail,
          password: managerPassword,
        );
        return null;
      }

      User? newWorker = workerCredential.user;

      if (newWorker != null) {
        // 4. Store worker's details in Firestore
        await FirestoreService.createUserDocument(
          newWorker.uid,
          workerName,
          'worker',
        );
        if (kDebugMode) {
          print("Worker account created and Firestore document added.");
        }

        // 5. Sign the manager back in
        await _auth.signInWithEmailAndPassword(
          email: managerEmail,
          password: managerPassword,
        );
        if (kDebugMode) {
          print("Manager signed back in.");
        }
        return newWorker; // Return the created worker user object
      } else {
        // Attempt to sign the manager back in if worker creation somehow resulted in null user
        await _auth.signInWithEmailAndPassword(
          email: managerEmail,
          password: managerPassword,
        );
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error in createWorkerAccount process: ${e.toString()}");
      }
      // Attempt to sign the manager back in if any other error occurred
      // This is a fallback, ensure the manager is signed in if possible
      try {
        if (_auth.currentUser == null) {
          await _auth.signInWithEmailAndPassword(
            email: managerEmail,
            password: managerPassword,
          );
        }
      } catch (signInError) {
        if (kDebugMode) {
          print("Error signing manager back in after failure: $signInError");
        }
      }
      return null;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      // Consider returning a more specific error or using a result type
      return null;
    }
  }

  Future<User?> signUp(
    String email,
    String password,
    String name,
    String role,
  ) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await FirestoreService.createUserDocument(cred.user!.uid, name, role);
      }
      return cred.user;
    } catch (e) {
      if (kDebugMode) {
        print('Error signing up: ${e.toString()}');
      }
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: ${e.toString()}');
      }
    }
  }
}
