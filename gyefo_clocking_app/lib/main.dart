import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/screens/loading_screen.dart';
import 'package:gyefo_clocking_app/screens/new_login_screen.dart';
import 'package:gyefo_clocking_app/screens/modern_manager_dashboard.dart';
import 'package:gyefo_clocking_app/screens/modern_worker_dashboard.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';
import 'package:gyefo_clocking_app/services/simple_notification_service.dart';
import 'package:gyefo_clocking_app/services/offline_sync_service.dart';
import 'package:gyefo_clocking_app/services/navigation_service.dart';
import 'package:gyefo_clocking_app/services/fcm_notification_service.dart';
import 'package:gyefo_clocking_app/services/session_manager.dart';
import 'package:gyefo_clocking_app/widgets/logout_confirmation_dialog.dart';
import 'package:gyefo_clocking_app/themes/app_themes.dart';
import 'config/firebase_options_secure.dart';

void main() async {
  // Make main asynchronous
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase first using secure options
  await Firebase.initializeApp(options: SecureFirebaseOptions.currentPlatform);

  // Load saved theme preference
  await AppThemes.loadSavedTheme();

  // Initialize notifications
  await SimpleNotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppThemes.themeNotifier,
      builder: (_, ThemeMode themeMode, __) {
        return MaterialApp(
          title: 'Gyefo Clocking App',
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.navigatorKey,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeMode,
          home: const AuthWrapper(),
        );
      },
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
  final SessionManager _sessionManager = SessionManager();

  @override
  void initState() {
    super.initState();
    _initializeOfflineSync();
    _checkPendingNotifications();
    _initializeSessionManager();
  }

  @override
  void dispose() {
    _offlineSyncService.dispose();
    _sessionManager.dispose();
    super.dispose();
  }

  Future<void> _initializeOfflineSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _offlineSyncService.initialize();
    }
  }

  Future<void> _checkPendingNotifications() async {
    // Check for pending navigation intents from notifications
    await FCMNotificationService.handlePendingNavigation();
  }

  Future<void> _initializeSessionManager() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _sessionManager.initialize(onExpired: _handleSessionExpired);
    }
  }

  Future<void> _handleSessionExpired() async {
    // Show auto-logout dialog
    if (mounted && NavigationService.navigatorKey.currentContext != null) {
      final context = NavigationService.navigatorKey.currentContext!;
      await LogoutConfirmationDialog.show(
        context,
        isAutoLogout: true,
        reason: 'Your session has expired due to inactivity.',
      );
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
          // Initialize offline sync and session when user logs in
          _initializeOfflineSync();
          _initializeSessionManager();

          return FutureBuilder<String?>(
            future: FirestoreService.getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting ||
                  !roleSnapshot.hasData) {
                return const LoadingScreen();
              }
              final role = roleSnapshot.data!;
              if (role == 'manager') {
                return const ModernManagerDashboard();
              }
              return const ModernWorkerDashboard();
            },
          );
        } else {
          // User logged out, dispose session manager
          _sessionManager.dispose();
          return const LoginScreen(); // Using new Ghana-inspired login
        }
      },
    );
  }
}
