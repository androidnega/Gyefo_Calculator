import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/screens/loading_screen.dart';
import 'package:gyefo_clocking_app/screens/login_screen.dart';
import 'package:gyefo_clocking_app/screens/manager_dashboard.dart';
import 'package:gyefo_clocking_app/screens/worker_dashboard.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';
import 'package:gyefo_clocking_app/services/simple_notification_service.dart';
import 'package:gyefo_clocking_app/services/offline_sync_service.dart';

void main() async {
  // Make main asynchronous
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey:
          "AIzaSyCsgwd4NSd61zW5O09sRK0N_hySDQn9LfI", // Updated to match Google Maps key
      authDomain: "gyefo-clocks.firebaseapp.com",
      projectId: "gyefo-clocks",
      storageBucket: "gyefo-clocks.firebasestorage.app",
      messagingSenderId: "791824155693",
      appId: "1:791824155693:web:0622266e56fbf3cc8464a4",
    ),
  );
  // Initialize notifications
  await SimpleNotificationService.initialize();

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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final OfflineSyncService _offlineSyncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    _initializeOfflineSync();
  }

  @override
  void dispose() {
    _offlineSyncService.dispose();
    super.dispose();
  }

  Future<void> _initializeOfflineSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _offlineSyncService.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          // Initialize offline sync when user logs in
          _initializeOfflineSync();

          return FutureBuilder<String?>(
            future: FirestoreService.getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting ||
                  !roleSnapshot.hasData) {
                return const LoadingScreen();
              }

              final role = roleSnapshot.data!;
              if (role == 'manager') {
                return ManagerDashboard(
                  offlineSyncService: _offlineSyncService,
                );
              }
              return WorkerDashboard(offlineSyncService: _offlineSyncService);
            },
          );
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
