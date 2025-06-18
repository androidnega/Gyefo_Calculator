import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';

class ShiftAssignmentScreen extends StatefulWidget {
  final ShiftModel? shift;

  const ShiftAssignmentScreen({super.key, this.shift});

  @override
  State<ShiftAssignmentScreen> createState() => _ShiftAssignmentScreenState();
}

class _ShiftAssignmentScreenState extends State<ShiftAssignmentScreen> {
  final ShiftService _shiftService = ShiftService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ShiftModel> _shifts = [];
  List<UserModel> _workers = [];
  Map<String, String?> _workerShiftAssignments = {};
  bool _isLoading = false;
  bool _isUpdating = false;

  String? _selectedShiftId;

  @override
  void initState() {
    super.initState();
    _selectedShiftId = widget.shift?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load shifts
      final shifts = await _shiftService.getAllShifts();

      // Load workers
      final workersSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'worker')
              .where('isActive', isEqualTo: true)
              .get();

      final workers =
          workersSnapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();

      // Load current assignments
      final assignments = <String, String?>{};
      for (final worker in workers) {
        assignments[worker.uid] = worker.shiftId;
      }

      setState(() {
        _shifts = shifts;
        _workers = workers;
        _workerShiftAssignments = assignments;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.shift != null
              ? 'Assign Workers to ${widget.shift!.name}'
              : 'Manage Shift Assignments',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Shift Assignments',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Assign workers to their work shifts',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (widget.shift == null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Filter by Shift:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String?>(
                                value: _selectedShiftId,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'All shifts',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All shifts'),
                                  ),
                                  ..._shifts.map(
                                    (shift) => DropdownMenuItem(
                                      value: shift.id,
                                      child: Text(
                                        '${shift.name} (${shift.startTime} - ${shift.endTime})',
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedShiftId = value;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Workers List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Workers (${_getFilteredWorkers().length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_hasChanges())
                          ElevatedButton.icon(
                            onPressed: _isUpdating ? null : _saveChanges,
                            icon:
                                _isUpdating
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.save),
                            label: Text(
                              _isUpdating ? 'Saving...' : 'Save Changes',
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child:
                          _getFilteredWorkers().isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                itemCount: _getFilteredWorkers().length,
                                itemBuilder: (context, index) {
                                  final worker = _getFilteredWorkers()[index];
                                  return _buildWorkerCard(worker);
                                },
                              ),
                    ),
                  ],
                ),
              ),
    );
  }

  List<UserModel> _getFilteredWorkers() {
    if (_selectedShiftId == null) {
      return _workers;
    }
    return _workers
        .where(
          (worker) => _workerShiftAssignments[worker.uid] == _selectedShiftId,
        )
        .toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _selectedShiftId == null
                ? 'No workers found'
                : 'No workers assigned to this shift',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(UserModel worker) {
    final currentShiftId = _workerShiftAssignments[worker.uid];
    final currentShift =
        currentShiftId != null
            ? _shifts.firstWhere(
              (s) => s.id == currentShiftId,
              orElse:
                  () => ShiftModel(
                    id: 'unknown',
                    name: 'Unknown Shift',
                    startTime: '00:00',
                    endTime: '00:00',
                    workDays: [1, 2, 3, 4, 5],
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
            )
            : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    worker.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (worker.email != null)
                        Text(
                          worker.email!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Text(
                  'Assigned Shift:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: currentShiftId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No shift assigned'),
                      ),
                      ..._shifts.map(
                        (shift) => DropdownMenuItem(
                          value: shift.id,
                          child: Text(
                            '${shift.name} (${shift.startTime} - ${shift.endTime})',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _workerShiftAssignments[worker.uid] = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            if (currentShift != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildPropertyChip(
                    'Grace: ${currentShift.gracePeriodMinutes}min',
                    Icons.access_time,
                  ),
                  _buildPropertyChip(
                    currentShift.allowWeekends ? 'Weekends OK' : 'No Weekends',
                    currentShift.allowWeekends ? Icons.weekend : Icons.block,
                    color:
                        currentShift.allowWeekends
                            ? Colors.green
                            : Colors.orange,
                  ),
                  _buildPropertyChip(
                    currentShift.allowOvertime ? 'Overtime OK' : 'No Overtime',
                    currentShift.allowOvertime ? Icons.schedule : Icons.block,
                    color:
                        currentShift.allowOvertime ? Colors.blue : Colors.red,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyChip(String label, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.primary).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (color ?? Theme.of(context).colorScheme.primary).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasChanges() {
    return _workers.any(
      (worker) => _workerShiftAssignments[worker.uid] != worker.shiftId,
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isUpdating = true);

    try {
      final batch = _firestore.batch();

      for (final worker in _workers) {
        final newShiftId = _workerShiftAssignments[worker.uid];
        if (newShiftId != worker.shiftId) {
          final workerRef = _firestore.collection('users').doc(worker.uid);
          batch.update(workerRef, {'shiftId': newShiftId});
        }
      }

      await batch.commit();

      // Update local worker data
      for (final worker in _workers) {
        final newShiftId = _workerShiftAssignments[worker.uid];
        if (newShiftId != worker.shiftId) {
          final index = _workers.indexWhere((w) => w.uid == worker.uid);
          _workers[index] = worker.copyWith(shiftId: newShiftId);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift assignments updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving assignments: $e')));
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }
}
