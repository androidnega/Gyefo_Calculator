import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/user_model.dart'; // Assuming UserModel is needed for worker data
import 'package:gyefo_clocking_app/screens/worker_attendance_detail_screen.dart';
import 'package:gyefo_clocking_app/services/export_service.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:gyefo_clocking_app/widgets/attendance_chart.dart';
import 'package:gyefo_clocking_app/widgets/monthly_summary_card.dart';
import 'package:intl/intl.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  const ManagerAttendanceScreen({super.key});

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  bool _isExporting = false;

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
      appBar: AppBar(
        title: const Text('Worker Attendance Overview'),
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
              icon: const Icon(Icons.download),
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
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
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No workers found',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create worker accounts to see them here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final workers = snapshot.data!.docs;

          // Sort workers by name in the client to avoid index requirements
          workers.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aName = aData['name'] ?? '';
            final bName = bData['name'] ?? '';
            return aName.toString().compareTo(bName.toString());
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Total Workers: ${workers.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: workers.length,
                  separatorBuilder:
                      (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final workerData =
                        workers[index].data() as Map<String, dynamic>;
                    final worker = UserModel.fromMap(
                      workerData,
                      workers[index].id,
                    );

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          // Worker Header
                          InkWell(
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => WorkerAttendanceDetailScreen(
                                          workerId: worker.uid,
                                        ),
                                  ),
                                ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue.shade50,
                                    child: Text(
                                      worker.name.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          worker.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (worker.email != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            worker.email!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey,
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
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    8,
                                  ),
                                  child: AttendanceChart(
                                    weeklyHours: snapshot.data!,
                                    title: 'This Week\'s Hours',
                                  ),
                                );
                              }
                              return Container(
                                height: 200,
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
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
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: MonthlySummaryCard(
                                    totalDaysWorked: data['totalDaysWorked'],
                                    totalHours: data['totalHours'],
                                    totalRecords: data['totalRecords'],
                                    averageHoursPerDay:
                                        data['averageHoursPerDay'],
                                    month: data['month'],
                                  ),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
