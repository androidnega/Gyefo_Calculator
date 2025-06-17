import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthlySummaryCard extends StatelessWidget {
  final int totalDaysWorked;
  final double totalHours;
  final DateTime month;
  final int totalRecords;
  final double averageHoursPerDay;

  const MonthlySummaryCard({
    super.key,
    required this.totalDaysWorked,
    required this.totalHours,
    required this.month,
    this.totalRecords = 0,
    this.averageHoursPerDay = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(month);

    return Card(
      elevation: 3,
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Colors.indigo.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  "Monthly Summary - $monthName",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.event_available,
                    title: 'Days Worked',
                    value: '$totalDaysWorked',
                    subtitle:
                        totalRecords > totalDaysWorked
                            ? '$totalRecords total entries'
                            : null,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.schedule,
                    title: 'Total Hours',
                    value: totalHours.toStringAsFixed(1),
                    subtitle: 'hours worked',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.trending_up,
                    title: 'Avg Hours/Day',
                    value:
                        averageHoursPerDay > 0
                            ? averageHoursPerDay.toStringAsFixed(1)
                            : '0.0',
                    subtitle: 'per working day',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.calendar_month,
                    title: 'Work Days',
                    value: '${_getWorkingDaysInMonth()}',
                    subtitle: 'days in month',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            if (totalDaysWorked > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: Colors.indigo.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getInsightText(),
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  int _getWorkingDaysInMonth() {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    int workingDays = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      // Monday = 1, Sunday = 7
      if (date.weekday <= 5) {
        // Monday to Friday
        workingDays++;
      }
    }

    return workingDays;
  }

  String _getInsightText() {
    final workingDays = _getWorkingDaysInMonth();
    final attendanceRate = (totalDaysWorked / workingDays * 100);

    if (attendanceRate >= 90) {
      return 'Excellent attendance! ${attendanceRate.toStringAsFixed(0)}% of working days.';
    } else if (attendanceRate >= 75) {
      return 'Good attendance. ${attendanceRate.toStringAsFixed(0)}% of working days.';
    } else if (attendanceRate >= 50) {
      return 'Moderate attendance. ${attendanceRate.toStringAsFixed(0)}% of working days.';
    } else {
      return 'Low attendance. ${attendanceRate.toStringAsFixed(0)}% of working days.';
    }
  }
}
