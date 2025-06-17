import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/screens/loading_screen.dart';
import 'package:gyefo_clocking_app/screens/login_screen.dart';
import 'package:gyefo_clocking_app/screens/manager_dashboard.dart';
import 'package:gyefo_clocking_app/screens/worker_dashboard.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';
import 'package:gyefo_clocking_app/services/notification_service.dart';

void main() async {
  // Make main asynchronous
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyCsgwd4NSd61zW5O09sRK0N_hySDQn9LfI", // Updated to match Google Maps key
      authDomain: "gyefo-clocks.firebaseapp.com",
      projectId: "gyefo-clocks",
      storageBucket: "gyefo-clocks.firebasestorage.app",
      messagingSenderId: "791824155693",
      appId: "1:791824155693:web:0622266e56fbf3cc8464a4",
    ),
  );

  // Initialize notifications
  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gyefo Clocking App', // Changed title
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
        ), // Changed color scheme
        useMaterial3: true, // Enabled Material 3
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen();
          }
          if (snapshot.hasData) {
            return FutureBuilder<String?>(
              future: FirestoreService.getUserRole(snapshot.data!.uid),
              builder: (context, roleSnapshot) {
                // Changed snapshot name for clarity
                if (roleSnapshot.connectionState == ConnectionState.waiting ||
                    !roleSnapshot.hasData) {
                  return const LoadingScreen(); // Show loading while fetching role or if no data
                }
                final role = roleSnapshot.data!;
                if (role == 'manager') {
                  return const ManagerDashboard(); // Added const
                }
                return const WorkerDashboard(); // Added const
              },
            );
          } else {
            return const LoginScreen(); // Added const
          }
        },
      ),
    );
  }
}
