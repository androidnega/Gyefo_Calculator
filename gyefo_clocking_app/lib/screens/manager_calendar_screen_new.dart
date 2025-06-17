import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:intl/intl.dart';

class ManagerCalendarScreen extends StatefulWidget {
  final String workerId;
  const ManagerCalendarScreen({super.key, required this.workerId});

  @override
  State<ManagerCalendarScreen> createState() => _ManagerCalendarScreenState();
}

class _ManagerCalendarScreenState extends State<ManagerCalendarScreen> {
  Map<DateTime, List<AttendanceModel>> _attendanceMap = {};
  Map<DateTime, List<Map<String, dynamic>>> _holidayMap = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  UserModel? _workerInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadWorkerInfo();
    _fetchAttendance();
    _fetchHolidays();
  }

  Future<void> _loadWorkerInfo() async {
    try {
      final workerDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.workerId)
              .get();

      if (workerDoc.exists) {
        _workerInfo = UserModel.fromMap(workerDoc.data()!, workerDoc.id);
      }
    } catch (e) {
      AppLogger.error('Error loading worker info: $e');
    }
  }

  Future<void> _fetchAttendance() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('attendance')
              .doc(widget.workerId)
              .collection('records')
              .orderBy('clockIn', descending: true)
              .get();

      Map<DateTime, List<AttendanceModel>> tempMap = {};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final attendance = AttendanceModel.fromMap(data);

          // Normalize the date to ignore time component
          final normalizedDate = DateTime(
            attendance.clockIn.year,
            attendance.clockIn.month,
            attendance.clockIn.day,
          );

          if (tempMap[normalizedDate] == null) {
            tempMap[normalizedDate] = [];
          }
          tempMap[normalizedDate]!.add(attendance);
        } catch (e) {
          AppLogger.error('Error parsing attendance record: $e');
        }
      }

      setState(() {
        _attendanceMap = tempMap;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error fetching attendance: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHolidays() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('holidays').get();

      Map<DateTime, List<Map<String, dynamic>>> tempMap = {};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final holidayDate = (data['date'] as Timestamp).toDate();

          // Normalize the date to ignore time component
          final normalizedDate = DateTime(
            holidayDate.year,
            holidayDate.month,
            holidayDate.day,
          );

          if (tempMap[normalizedDate] == null) {
            tempMap[normalizedDate] = [];
          }
          tempMap[normalizedDate]!.add({
            'id': doc.id,
            'name': data['name'],
            'date': holidayDate,
          });
        } catch (e) {
          AppLogger.error('Error parsing holiday record: $e');
        }
      }

      setState(() {
        _holidayMap = tempMap;
      });
    } catch (e) {
      AppLogger.error('Error fetching holidays: $e');
    }
  }

  List<AttendanceModel> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _attendanceMap[normalizedDay] ?? [];
  }

  List<Map<String, dynamic>> _getHolidaysForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _holidayMap[normalizedDay] ?? [];
  }

  void _showDayDetails(DateTime selectedDay) {
    final events = _getEventsForDay(selectedDay);
    final holidays = _getHolidaysForDay(selectedDay);
    final dateString = DateFormat('EEEE, MMMM d, yyyy').format(selectedDay);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            expand: false,
            builder:
                (context, scrollController) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dateString,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Content
                      Expanded(
                        child: Column(
                          children: [
                            // Show holidays first if any
                            if (holidays.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.celebration,
                                          color: Colors.red.shade600,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Holidays',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...holidays.map(
                                      (holiday) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          '• ${holiday['name']}',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Attendance events
                            Expanded(
                              child:
                                  events.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.event_busy,
                                              size: 64,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No attendance recorded',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Worker did not clock in on this day',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : ListView.builder(
                                        controller: scrollController,
                                        itemCount: events.length,
                                        itemBuilder: (context, index) {
                                          final attendance = events[index];
                                          final clockInTime = DateFormat(
                                            'HH:mm:ss',
                                          ).format(attendance.clockIn);
                                          final clockOutTime =
                                              attendance.clockOut != null
                                                  ? DateFormat(
                                                    'HH:mm:ss',
                                                  ).format(attendance.clockOut!)
                                                  : 'Not clocked out';

                                          String hoursWorked = 'Still working';
                                          Color statusColor = Colors.orange;

                                          if (attendance.clockOut != null) {
                                            final duration = attendance
                                                .clockOut!
                                                .difference(attendance.clockIn);
                                            final hours = duration.inHours;
                                            final minutes =
                                                duration.inMinutes % 60;
                                            hoursWorked =
                                                '${hours}h ${minutes}m';
                                            statusColor = Colors.green;
                                          }

                                          return Card(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: statusColor
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          attendance.clockOut !=
                                                                  null
                                                              ? 'Completed'
                                                              : 'In Progress',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: statusColor,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      if (events.length > 1)
                                                        Text(
                                                          'Session ${index + 1}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),

                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: _buildTimeInfo(
                                                          icon: Icons.login,
                                                          label: 'Clock In',
                                                          time: clockInTime,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: _buildTimeInfo(
                                                          icon: Icons.logout,
                                                          label: 'Clock Out',
                                                          time: clockOutTime,
                                                          color:
                                                              attendance.clockOut !=
                                                                      null
                                                                  ? Colors.red
                                                                  : Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  if (attendance.clockOut !=
                                                      null) ...[
                                                    const SizedBox(height: 12),
                                                    const Divider(),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.timer,
                                                          size: 16,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade600,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          'Total Time: ',
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                          ),
                                                        ),
                                                        Text(
                                                          hoursWorked,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Attendance'),
            if (_workerInfo != null)
              Text(
                _workerInfo!.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Calendar
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: TableCalendar<AttendanceModel>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate:
                          (day) => isSameDay(_selectedDay, day),
                      calendarFormat: CalendarFormat.month,
                      eventLoader: _getEventsForDay,
                      holidayPredicate:
                          (day) => _getHolidaysForDay(day).isNotEmpty,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                      },
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        weekendTextStyle: TextStyle(color: Colors.red.shade600),
                        holidayTextStyle: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        markersMaxCount: 3,
                        markerDecoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                        ),
                        holidayDecoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.blue.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Colors.blue.shade700,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Colors.blue.shade700,
                        ),
                        titleTextStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _showDayDetails(selectedDay);
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                    ),
                  ),

                  // Legend and Statistics
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calendar Legend',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              _buildLegendItem(
                                color: Colors.blue.shade600,
                                label: 'Has attendance records',
                              ),
                              const SizedBox(width: 20),
                              _buildLegendItem(
                                color: Colors.blue.shade700,
                                label: 'Selected day',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildLegendItem(
                                color: Colors.blue.shade400,
                                label: 'Today',
                              ),
                              const SizedBox(width: 20),
                              _buildLegendItem(
                                color: Colors.red.shade600,
                                label: 'Weekend',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildLegendItem(
                                color: Colors.red.shade300,
                                label: 'Holiday',
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Quick Stats
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quick Statistics',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatItem(
                                          label: 'Days with Records',
                                          value: '${_attendanceMap.length}',
                                          icon: Icons.event_available,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildStatItem(
                                          label: 'Total Sessions',
                                          value:
                                              '${_attendanceMap.values.fold(0, (total, list) => total + list.length)}',
                                          icon: Icons.access_time,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatItem(
                                          label: 'Total Holidays',
                                          value:
                                              '${_holidayMap.values.fold(0, (total, list) => total + list.length)}',
                                          icon: Icons.celebration,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const Spacer(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
