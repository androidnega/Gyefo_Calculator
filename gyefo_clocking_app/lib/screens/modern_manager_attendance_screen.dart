import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/screens/worker_attendance_detail_screen.dart';
import 'package:gyefo_clocking_app/services/export_service.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:gyefo_clocking_app/utils/app_theme.dart';
import 'package:gyefo_clocking_app/widgets/attendance_chart.dart';
import 'package:gyefo_clocking_app/widgets/monthly_summary_card.dart';
import 'package:intl/intl.dart';

enum ViewMode { list, cards }

class ManagerAttendanceScreen extends StatefulWidget {
  const ManagerAttendanceScreen({super.key});

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  bool _isExporting = false;
  ViewMode _currentView = ViewMode.list;

  /// Calculate today's status for a worker
  Future<Map<String, dynamic>> _calculateTodaysStatus(String workerId) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final snapshot =
          await FirebaseFirestore.instance
              .collection('attendance')
              .doc(workerId)
              .collection('records')
              .where('date', isEqualTo: today)
              .get();

      if (snapshot.docs.isEmpty) {
        return {'isPresent': false, 'hoursToday': 0.0};
      }

      double totalHours = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final clockIn = DateTime.parse(data['clockIn']);
        final clockOutString = data['clockOut'];

        if (clockOutString != null) {
          final clockOut = DateTime.parse(clockOutString);
          final duration = clockOut.difference(clockIn);
          totalHours += duration.inMinutes / 60.0;
        }
      }

      return {'isPresent': true, 'hoursToday': totalHours};
    } catch (e) {
      AppLogger.error(
        'Error calculating today\'s status for worker $workerId: $e',
      );
      return {'isPresent': false, 'hoursToday': 0.0};
    }
  }

  /// Calculate weekly summary for a worker
  Future<Map<String, dynamic>> _calculateWeeklySummary(String workerId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final startDateString = DateFormat('yyyy-MM-dd').format(startOfWeek);
      final endDateString = DateFormat('yyyy-MM-dd').format(endOfWeek);

      final snapshot =
          await FirebaseFirestore.instance
              .collection('attendance')
              .doc(workerId)
              .collection('records')
              .where('date', isGreaterThanOrEqualTo: startDateString)
              .where('date', isLessThanOrEqualTo: endDateString)
              .get();

      double totalHours = 0.0;
      Set<String> workedDays = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = data['date'];
        final clockIn = DateTime.parse(data['clockIn']);
        final clockOutString = data['clockOut'];

        workedDays.add(date);

        if (clockOutString != null) {
          final clockOut = DateTime.parse(clockOutString);
          final duration = clockOut.difference(clockIn);
          totalHours += duration.inMinutes / 60.0;
        }
      }

      return {'totalHours': totalHours, 'daysWorked': workedDays.length};
    } catch (e) {
      AppLogger.error(
        'Error calculating weekly summary for worker $workerId: $e',
      );
      return {'totalHours': 0.0, 'daysWorked': 0};
    }
  }

  /// Calculate team statistics
  Future<Map<String, dynamic>> _calculateTeamStats(
    List<QueryDocumentSnapshot> workers,
  ) async {
    try {
      int presentToday = 0;
      double totalWeeklyHours = 0.0;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      for (var worker in workers) {
        final workerId = worker.id;

        // Check if present today
        final todaySnapshot =
            await FirebaseFirestore.instance
                .collection('attendance')
                .doc(workerId)
                .collection('records')
                .where('date', isEqualTo: today)
                .get();

        if (todaySnapshot.docs.isNotEmpty) {
          presentToday++;
        }

        // Calculate weekly hours
        final weeklyData = await _calculateWeeklySummary(workerId);
        totalWeeklyHours += weeklyData['totalHours'] as double;
      }

      return {'presentToday': presentToday, 'totalHours': totalWeeklyHours};
    } catch (e) {
      AppLogger.error('Error calculating team stats: $e');
      return {'presentToday': 0, 'totalHours': 0.0};
    }
  }

  /// Calculate weekly hours for a specific worker
  Future<List<double>> _calculateWeeklyHours(String workerId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      List<double> weeklyHours = List.filled(7, 0.0);

      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);

        final snapshot =
            await FirebaseFirestore.instance
                .collection('attendance')
                .doc(workerId)
                .collection('records')
                .where('date', isEqualTo: dateString)
                .get();

        double dayHours = 0.0;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final clockIn = DateTime.parse(data['clockIn']);
          final clockOutString = data['clockOut'];

          if (clockOutString != null) {
            final clockOut = DateTime.parse(clockOutString);
            final duration = clockOut.difference(clockIn);
            dayHours += duration.inMinutes / 60.0;
          }
        }
        weeklyHours[i] = dayHours;
      }

      return weeklyHours;
    } catch (e) {
      AppLogger.error(
        'Error calculating weekly hours for worker $workerId: $e',
      );
      return List.filled(7, 0.0);
    }
  }

  /// Calculate monthly summary for a specific worker
  Future<Map<String, dynamic>> _calculateMonthlySummary(String workerId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final startDateString = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endDateString = DateFormat('yyyy-MM-dd').format(endOfMonth);

      final snapshot =
          await FirebaseFirestore.instance
              .collection('attendance')
              .doc(workerId)
              .collection('records')
              .where('date', isGreaterThanOrEqualTo: startDateString)
              .where('date', isLessThanOrEqualTo: endDateString)
              .get();

      double totalHours = 0.0;
      Set<String> workedDays = {};
      int totalRecords = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = data['date'];
        final clockIn = DateTime.parse(data['clockIn']);
        final clockOutString = data['clockOut'];

        totalRecords++;
        workedDays.add(date);

        if (clockOutString != null) {
          final clockOut = DateTime.parse(clockOutString);
          final duration = clockOut.difference(clockIn);
          totalHours += duration.inMinutes / 60.0;
        }
      }

      return {
        'totalDaysWorked': workedDays.length,
        'totalHours': totalHours,
        'totalRecords': totalRecords,
        'averageHoursPerDay':
            workedDays.isNotEmpty ? totalHours / workedDays.length : 0.0,
        'month': startOfMonth,
      };
    } catch (e) {
      AppLogger.error(
        'Error calculating monthly summary for worker $workerId: $e',
      );
      return {
        'totalDaysWorked': 0,
        'totalHours': 0.0,
        'totalRecords': 0,
        'averageHoursPerDay': 0.0,
        'month': DateTime.now(),
      };
    }
  }

  /// Build a compact worker card for list view
  Widget _buildCompactWorkerCard(UserModel worker) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => WorkerAttendanceDetailScreen(workerId: worker.uid),
              ),
            ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Worker Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.clockInGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    worker.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: AppColors.clockInGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Worker Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _calculateTodaysStatus(worker.uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final data = snapshot.data!;
                          final isPresent = data['isPresent'] as bool;
                          final hoursToday = data['hoursToday'] as double;

                          return Row(
                            children: [
                              // Status indicator
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      isPresent
                                          ? AppColors.clockInGreen
                                          : AppColors.flaggedRed,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isPresent
                                    ? 'Present • ${hoursToday.toStringAsFixed(1)}h today'
                                    : 'Absent today',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            ],
                          );
                        }
                        return Text(
                          'Loading status...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textLight,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Weekly summary
              FutureBuilder<Map<String, dynamic>>(
                future: _calculateWeeklySummary(worker.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final data = snapshot.data!;
                    final weeklyHours = data['totalHours'] as double;
                    final daysWorked = data['daysWorked'] as int;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${weeklyHours.toStringAsFixed(1)}h',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          '$daysWorked/7 days',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build overview statistics card
  Widget _buildOverviewStats(List<QueryDocumentSnapshot> workers) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.clockInGreen,
            AppColors.clockInGreen.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.clockInGreen.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Team Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats Row
          FutureBuilder<Map<String, dynamic>>(
            future: _calculateTeamStats(workers),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final stats = snapshot.data!;
                return Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total Workers',
                        '${workers.length}',
                        Icons.people_rounded,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Present Today',
                        '${stats['presentToday']}',
                        Icons.check_circle_rounded,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Total Hours',
                        '${stats['totalHours'].toStringAsFixed(0)}h',
                        Icons.schedule_rounded,
                      ),
                    ),
                  ],
                );
              }
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build view toggle buttons
  Widget _buildViewToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('List View', Icons.list_rounded, ViewMode.list),
          _buildToggleButton(
            'Card View',
            Icons.view_module_rounded,
            ViewMode.cards,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, IconData icon, ViewMode mode) {
    final isSelected = _currentView == mode;
    return GestureDetector(
      onTap: () => setState(() => _currentView = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.clockInGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppTheme.textLight,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textLight,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAllWorkersAttendance() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final file = await ExportService.exportAllWorkersAttendance();

      if (mounted) {
        if (file != null) {
          _showExportSuccessDialog(file);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to export attendance records'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _showExportSuccessDialog(File file) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Export Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All workers\' attendance records exported to:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    file.path,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await ExportService.shareCSVFile(file, 'All Workers');
                },
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      appBar: AppBar(
        title: const Text(
          'Team Attendance',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.download_rounded,
                color: AppTheme.textDark,
              ),
              onPressed: _exportAllWorkersAttendance,
              tooltip: 'Export All Workers Attendance',
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'worker')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.flaggedRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading workers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 80,
                    color: AppTheme.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Workers Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create worker accounts to see attendance data here',
                    style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final workers = snapshot.data!.docs;

          // Sort workers by name
          workers.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aName = aData['name'] ?? '';
            final bName = bData['name'] ?? '';
            return aName.toString().compareTo(bName.toString());
          });

          return Column(
            children: [
              // Overview Stats
              _buildOverviewStats(workers),

              // View Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_buildViewToggle()],
              ),

              const SizedBox(height: 16),

              // Workers List/Grid
              Expanded(
                child:
                    _currentView == ViewMode.list
                        ? _buildListView(workers)
                        : _buildCardView(workers),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListView(List<QueryDocumentSnapshot> workers) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final workerData = workers[index].data() as Map<String, dynamic>;
        final worker = UserModel.fromMap(workerData, workers[index].id);
        return _buildCompactWorkerCard(worker);
      },
    );
  }

  Widget _buildCardView(List<QueryDocumentSnapshot> workers) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final workerData = workers[index].data() as Map<String, dynamic>;
        final worker = UserModel.fromMap(workerData, workers[index].id);
        return _buildDetailedWorkerCard(worker);
      },
    );
  }

  Widget _buildDetailedWorkerCard(UserModel worker) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Worker Header
          InkWell(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                            WorkerAttendanceDetailScreen(workerId: worker.uid),
                  ),
                ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.clockInGreen,
                          AppColors.clockInGreen.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        worker.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        if (worker.email != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            worker.email!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 20,
                    color: AppTheme.textLight,
                  ),
                ],
              ),
            ),
          ),

          // Weekly Chart
          FutureBuilder<List<double>>(
            future: _calculateWeeklyHours(worker.uid),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: AttendanceChart(
                    weeklyHours: snapshot.data!,
                    title: 'This Week\'s Hours',
                  ),
                );
              }
              return Container(
                height: 150,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),

          // Monthly Summary
          FutureBuilder<Map<String, dynamic>>(
            future: _calculateMonthlySummary(worker.uid),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final data = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: MonthlySummaryCard(
                    totalDaysWorked: data['totalDaysWorked'],
                    totalHours: data['totalHours'],
                    totalRecords: data['totalRecords'],
                    averageHoursPerDay: data['averageHoursPerDay'],
                    month: data['month'],
                  ),
                );
              }
              return const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ],
      ),
    );
  }
}
