import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gyefo_clocking_app/utils/app_theme.dart';
import 'package:gyefo_clocking_app/services/auth_service.dart';
import 'package:gyefo_clocking_app/services/attendance_service.dart';
import 'package:gyefo_clocking_app/services/offline_sync_service.dart';
import 'package:gyefo_clocking_app/screens/worker_attendance_detail_screen.dart';
import 'package:gyefo_clocking_app/screens/worker_flagged_records_screen.dart';
import 'package:gyefo_clocking_app/widgets/notification_bell.dart';
import 'package:gyefo_clocking_app/screens/messages_screen.dart';
import 'package:gyefo_clocking_app/services/message_service.dart';

class ModernWorkerDashboard extends StatefulWidget {
  final OfflineSyncService? offlineSyncService;

  const ModernWorkerDashboard({super.key, this.offlineSyncService});

  @override
  State<ModernWorkerDashboard> createState() => _ModernWorkerDashboardState();
}

class _ModernWorkerDashboardState extends State<ModernWorkerDashboard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late TabController _tabController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  bool _isClockedIn = false;
  bool _isLoading = false;
  String? _todayShift;
  DateTime? _lastClockTime;
  String _workerName = '';
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _tabController = TabController(length: 2, vsync: this);
    _loadWorkerData();
    _startAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  void _startAnimations() {
    _fadeController.forward();
  }
  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final attendanceService = AttendanceService();

      // Check if worker is currently clocked in
      final isClockedIn = await attendanceService.hasClockedInToday(user.uid);

      setState(() {
        _workerName = user.displayName ?? 'Worker';
        _todayShift = 'Morning Shift (8:00 AM - 5:00 PM)';
        _isClockedIn = isClockedIn;
      });
    } catch (e) {
      // Handle error silently or show debug info
      setState(() {
        _workerName =
            FirebaseAuth.instance.currentUser?.displayName ?? 'Worker';
        _todayShift = 'Morning Shift (8:00 AM - 5:00 PM)';
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildClockButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isClockedIn ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: _isLoading ? null : _handleClockAction,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors:
                      _isClockedIn
                          ? [
                            AppColors.clockOutBlue,
                            AppColors.clockOutBlue.withValues(alpha: 0.8),
                          ]
                          : [
                            AppColors.clockInGreen,
                            AppColors.clockInGreen.withValues(alpha: 0.8),
                          ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isClockedIn
                            ? AppColors.clockOutBlue
                            : AppColors.clockInGreen)
                        .withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isClockedIn ? Icons.logout : Icons.login,
                            size: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isClockedIn ? 'Clock Out' : 'Clock In',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isClockedIn && _lastClockTime != null) ...[
                            const SizedBox(height: 8),
                            StreamBuilder<DateTime>(
                              stream: Stream.periodic(
                                const Duration(seconds: 1),
                                (_) => DateTime.now(),
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    _lastClockTime != null) {
                                  final duration = snapshot.data!.difference(
                                    _lastClockTime!,
                                  );
                                  final hours = duration.inHours;
                                  final minutes = (duration.inMinutes % 60);
                                  final seconds = (duration.inSeconds % 60);

                                  return Text(
                                    '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ],
                      ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleClockAction() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final attendanceService = AttendanceService();

      if (_isClockedIn) {
        // Clock out
        await attendanceService.clockOut(user.uid);
        setState(() {
          _isClockedIn = false;
          _lastClockTime = DateTime.now();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully clocked out!'),
              backgroundColor: AppColors.clockOutBlue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Clock in
        await attendanceService.clockIn(user.uid);
        setState(() {
          _isClockedIn = true;
          _lastClockTime = DateTime.now();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully clocked in!'),
              backgroundColor: AppColors.clockInGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildWelcomeHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}, $_workerName',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ready to start your day?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (_isClockedIn
                              ? AppColors.clockInGreen
                              : AppColors.clockOutBlue)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isClockedIn ? Icons.work : Icons.work_off,
                      color:
                          _isClockedIn
                              ? AppColors.clockInGreen
                              : AppColors.clockOutBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Status',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textLight),
                        ),
                        Text(
                          _isClockedIn ? 'Clocked In' : 'Clocked Out',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                _isClockedIn
                                    ? AppColors.clockInGreen
                                    : AppColors.clockOutBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_lastClockTime != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppTheme.textLight,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Last action: ${_formatTime(_lastClockTime!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Today\'s Shift',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_todayShift != null)
                Text(_todayShift!, style: Theme.of(context).textTheme.bodyLarge)
              else
                Text(
                  'No shift assigned for today',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppTheme.textLight),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Attendance',
                  Icons.access_time,
                  AppColors.clockInGreen,
                  () => Navigator.push(
                    context,
                    AppTheme.createPageRoute(
                      WorkerAttendanceDetailScreen(
                        workerId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      ),
                      routeName: '/worker-attendance',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  'Flagged Records',
                  Icons.flag,
                  AppTheme.errorRed,
                  () => Navigator.push(
                    context,
                    AppTheme.createPageRoute(
                      const WorkerFlaggedRecordsScreen(),
                      routeName: '/worker-flagged',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.surfaceWhite,
        title: Text(
          'Dashboard',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),        actions: [
          StreamBuilder<int>(
            stream: MessageService.getUnreadMessageCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      _tabController.animateTo(1);
                    },
                    icon: const Icon(Icons.message, color: AppTheme.textDark),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          NotificationBell(
            managerId: FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: AppTheme.errorRed),
                        SizedBox(width: 12),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textDark.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'Messages', icon: Icon(Icons.message)),
          ],
        ),
      ),      body: TabBarView(
        controller: _tabController,
        children: [
          // Dashboard Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                _buildWelcomeHeader(),
                const SizedBox(height: 32),

                // Clock Button
                Center(child: _buildClockButton()),
                const SizedBox(height: 32),

                // Status Card
                _buildStatusCard(),
                const SizedBox(height: 16),

                // Shift Card
                _buildShiftCard(),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(),
              ],
            ),
          ),
          // Messages Tab
          const MessagesScreen(),
        ],
      ),
    );
  }
}
