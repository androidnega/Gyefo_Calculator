import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/screens/add_holiday_screen.dart';
import 'package:intl/intl.dart';

class HolidayListScreen extends StatefulWidget {
  const HolidayListScreen({super.key});

  @override
  State<HolidayListScreen> createState() => _HolidayListScreenState();
}

class _HolidayListScreenState extends State<HolidayListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _holidays = [];

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('holidays')
          .orderBy('date')
          .get();

      List<Map<String, dynamic>> holidays = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        holidays.add({
          'id': doc.id,
          'name': data['name'],
          'date': (data['date'] as Timestamp).toDate(),
        });
      }

      setState(() {
        _holidays = holidays;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading holidays: $e')),
        );
      }
    }
  }

  Future<void> _deleteHoliday(String holidayId, String holidayName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Are you sure you want to delete "$holidayName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('holidays')
            .doc(holidayId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Holiday deleted successfully')),
          );
          _loadHolidays(); // Reload the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting holiday: $e')),
          );
        }
      }
    }
  }

  void _navigateToAddHoliday() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddHolidayScreen()),
    );
    
    // Reload holidays if a new one was added
    if (result == true || mounted) {
      _loadHolidays();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Holidays'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToAddHoliday,
            tooltip: 'Add Holiday',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _holidays.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.celebration_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Holidays Added',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add your first holiday',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHolidays,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _holidays.length,
                    itemBuilder: (context, index) {
                      final holiday = _holidays[index];
                      final holidayDate = holiday['date'] as DateTime;
                      final isUpcoming = holidayDate.isAfter(DateTime.now());
                      final isPast = holidayDate.isBefore(DateTime.now());
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isUpcoming 
                                  ? Colors.blue.shade100
                                  : isPast 
                                      ? Colors.grey.shade100 
                                      : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.celebration,
                              color: isUpcoming 
                                  ? Colors.blue.shade700
                                  : isPast 
                                      ? Colors.grey.shade600 
                                      : Colors.green.shade700,
                            ),
                          ),
                          title: Text(
                            holiday['name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isPast ? Colors.grey.shade600 : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy').format(holidayDate),
                                style: TextStyle(
                                  color: isPast ? Colors.grey.shade500 : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isUpcoming 
                                      ? Colors.blue.shade50
                                      : isPast 
                                          ? Colors.grey.shade50 
                                          : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isUpcoming 
                                      ? 'Upcoming'
                                      : isPast 
                                          ? 'Past' 
                                          : 'Today',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isUpcoming 
                                        ? Colors.blue.shade700
                                        : isPast 
                                            ? Colors.grey.shade600 
                                            : Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () => _deleteHoliday(
                              holiday['id'],
                              holiday['name'],
                            ),
                            tooltip: 'Delete Holiday',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddHoliday,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
