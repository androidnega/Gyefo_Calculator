import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/team_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/services/team_service.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamFormScreen extends StatefulWidget {
  final TeamModel? team;

  const TeamFormScreen({super.key, this.team});

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TeamService _teamService = TeamService();
  final ShiftService _shiftService = ShiftService();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  String? _selectedShiftId;
  List<ShiftModel> _availableShifts = [];
  bool _isActive = true;
  bool _isSaving = false;
  bool _isLoadingShifts = true;

  bool get _isEditing => widget.team != null;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadShifts();
    if (_isEditing) {
      _loadTeamData();
    }
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  void _loadTeamData() {
    final team = widget.team!;
    _nameController.text = team.name;
    _descriptionController.text = team.description ?? '';
    _selectedShiftId = team.shiftId;
    _isActive = team.isActive;
  }

  Future<void> _loadShifts() async {
    try {
      final shifts = await _shiftService.getAllShifts();
      setState(() {
        _availableShifts = shifts.where((shift) => shift.isActive).toList();
        _isLoadingShifts = false;
      });
    } catch (e) {
      AppLogger.error('Error loading shifts: $e');
      setState(() => _isLoadingShifts = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final team = TeamModel(
        id: _isEditing ? widget.team!.id : '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        managerId: _isEditing ? widget.team!.managerId : currentUser.uid,
        memberIds: _isEditing ? widget.team!.memberIds : [],
        shiftId: _selectedShiftId,
        isActive: _isActive,
        createdAt: _isEditing ? widget.team!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = _isEditing 
          ? await _teamService.updateTeam(team)
          : await _teamService.createTeam(team) != null;

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team ${_isEditing ? 'updated' : 'created'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${_isEditing ? 'updating' : 'creating'} team'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error saving team: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${_isEditing ? 'updating' : 'creating'} team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Team' : 'Create Team'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveTeam,
              child: Text(
                _isEditing ? 'UPDATE' : 'SAVE',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildShiftAssignmentSection(),
              const SizedBox(height: 24),
              _buildSettingsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                hintText: 'e.g., Marketing Team, Engineering',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a team name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description of the team',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftAssignmentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shift Assignment',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingShifts)
              const Center(child: CircularProgressIndicator())
            else if (_availableShifts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No active shifts available. Create shifts first to assign to teams.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedShiftId,
                decoration: const InputDecoration(
                  labelText: 'Assign Shift (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No shift assigned'),
                  ),
                  ..._availableShifts.map((shift) => DropdownMenuItem<String>(
                        value: shift.id,
                        child: Text('${shift.name} (${shift.startTime} - ${shift.endTime})'),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedShiftId = value;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Whether this team is currently in use'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
