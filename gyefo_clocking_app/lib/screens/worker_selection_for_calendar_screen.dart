import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/screens/manager_calendar_screen_new.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class WorkerSelectionForCalendarScreen extends StatefulWidget {
  const WorkerSelectionForCalendarScreen({super.key});

  @override
  State<WorkerSelectionForCalendarScreen> createState() =>
      _WorkerSelectionForCalendarScreenState();
}

class _WorkerSelectionForCalendarScreenState
    extends State<WorkerSelectionForCalendarScreen> {
  List<UserModel> _workers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    try {
      setState(() => _isLoading = true);

      final workersSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'worker')
              .orderBy('name')
              .get();

      final workers =
          workersSnapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();

      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading workers: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
      }
    }
  }

  List<UserModel> get _filteredWorkers {
    if (_searchQuery.isEmpty) return _workers;

    return _workers
        .where(
          (worker) =>
              worker.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (worker.email?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  void _navigateToWorkerCalendar(UserModel worker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagerCalendarScreen(workerId: worker.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Worker')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search workers',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Workers List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredWorkers.isEmpty
                    ? _buildEmptyState()
                    : _buildWorkersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No workers found'
                : 'No workers match your search',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Add workers through the Create Worker Account feature'
                : 'Try a different search term',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _filteredWorkers.length,
      itemBuilder: (context, index) {
        final worker = _filteredWorkers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                worker.name.isNotEmpty
                    ? worker.name.substring(0, 1).toUpperCase()
                    : 'W',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              worker.name.isNotEmpty ? worker.name : 'Unnamed Worker',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.email ?? 'No email'),
                if (worker.department?.isNotEmpty == true)
                  Text(
                    'Department: ${worker.department}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () => _navigateToWorkerCalendar(worker),
          ),
        );
      },
    );
  }
}
