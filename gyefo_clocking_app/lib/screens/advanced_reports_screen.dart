import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/models/team_model.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/services/team_service.dart';
import 'package:gyefo_clocking_app/services/shift_service.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:intl/intl.dart';

class AdvancedReportsScreen extends StatefulWidget {
  const AdvancedReportsScreen({super.key});

  @override
  State<AdvancedReportsScreen> createState() => _AdvancedReportsScreenState();
}

class _AdvancedReportsScreenState extends State<AdvancedReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
    final TeamService _teamService = TeamService();
  final ShiftService _shiftService = ShiftService();

  DateTimeRange? _selectedDateRange;
  String? _selectedTeamId;
  String? _selectedShiftId;
    List<TeamModel> _teams = [];
  List<ShiftModel> _shifts = [];
  
  bool _isLoading = false;
  Map<String, dynamic> _analytics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final teams = await _teamService.getAllTeams();
      final shifts = await _shiftService.getAllShifts();
      setState(() {
        _teams = teams;
        _shifts = shifts;
      });
      await _generateReport();
    } catch (e) {
      AppLogger.error('Error loading initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      await _generateReport();
    }
  }

  Future<void> _generateReport() async {
    if (_selectedDateRange == null) return;

    setState(() => _isLoading = true);
    try {
      // This is a simplified implementation
      // In a real app, you'd have more sophisticated queries
      final analytics = {
        'totalDays': _selectedDateRange!.duration.inDays,
        'totalEmployees': _teams.fold<int>(0, (sum, team) => sum + team.memberIds.length),
        'activeTeams': _teams.where((team) => team.isActive).length,
        'activeShifts': _shifts.where((shift) => shift.isActive).length,
      };

      setState(() {
        _analytics = analytics;
      });
    } catch (e) {
      AppLogger.error('Error generating report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Team Analytics', icon: Icon(Icons.groups)),
            Tab(text: 'Time Tracking', icon: Icon(Icons.schedule)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTeamAnalyticsTab(),
                _buildTimeTrackingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateRangeButton(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTeamDropdown(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildShiftDropdown(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeButton() {
    return OutlinedButton.icon(
      onPressed: _selectDateRange,
      icon: const Icon(Icons.date_range),
      label: Text(
        _selectedDateRange != null
            ? '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}'
            : 'Select Date Range',
      ),
    );
  }

  Widget _buildTeamDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedTeamId,
      decoration: const InputDecoration(
        labelText: 'Team',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Teams'),
        ),
        ..._teams.map((team) => DropdownMenuItem<String>(
              value: team.id,
              child: Text(team.name),
            )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedTeamId = value;
        });
        _generateReport();
      },
    );
  }

  Widget _buildShiftDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedShiftId,
      decoration: const InputDecoration(
        labelText: 'Shift',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Shifts'),
        ),
        ..._shifts.map((shift) => DropdownMenuItem<String>(
              value: shift.id,
              child: Text(shift.name),
            )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedShiftId = value;
        });
        _generateReport();
      },
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildQuickInsights(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Employees',
          '${_analytics['totalEmployees'] ?? 0}',
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Active Teams',
          '${_analytics['activeTeams'] ?? 0}',
          Icons.groups,
          Colors.green,
        ),
        _buildStatCard(
          'Active Shifts',
          '${_analytics['activeShifts'] ?? 0}',
          Icons.schedule,
          Colors.orange,
        ),
        _buildStatCard(
          'Report Period',
          '${_analytics['totalDays'] ?? 0} days',
          Icons.calendar_today,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInsights() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Insights',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildInsightItem(
              Icons.trending_up,
              'Team Performance',
              'Most teams are performing well with regular attendance',
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildInsightItem(
              Icons.schedule,
              'Shift Coverage',
              'All shifts have adequate coverage for the selected period',
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildInsightItem(
              Icons.warning,
              'Areas for Improvement',
              'Consider reviewing late arrival patterns',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(IconData icon, String title, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamAnalyticsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTeamPerformanceChart(),
          const SizedBox(height: 16),
          _buildTeamList(),
        ],
      ),
    );
  }

  Widget _buildTeamPerformanceChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Performance Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Performance Chart\n(Chart implementation would go here)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _teams.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final team = _teams[index];
                return _buildTeamTile(team);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamTile(TeamModel team) {
    return ListTile(      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: Text(
          team.name[0].toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(team.name),
      subtitle: Text('${team.memberIds.length} members'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),        decoration: BoxDecoration(
          color: team.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          team.isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            color: team.isActive ? Colors.green : Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeTrackingTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTimeAnalytics(),
          const SizedBox(height: 16),
          _buildShiftAnalytics(),
        ],
      ),
    );
  }

  Widget _buildTimeAnalytics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time Tracking Analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Time Analytics Chart\n(Implementation would show hourly breakdowns)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftAnalytics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shift Analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shifts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final shift = _shifts[index];
                return _buildShiftTile(shift);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftTile(ShiftModel shift) {
    return ListTile(
      leading: Icon(
        Icons.schedule,
        color: shift.isActive ? Colors.green : Colors.grey,
      ),
      title: Text(shift.name),
      subtitle: Text('${shift.startTime} - ${shift.endTime}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            shift.isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: shift.isActive ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${shift.workDays.length} days/week',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
