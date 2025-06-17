class ShiftModel {
  final String id;
  final String name;
  final String startTime; // "08:00"
  final String endTime; // "17:00"
  final List<int> workDays; // [1,2,3,4,5] for Mon-Fri
  final int gracePeriodMinutes;
  final bool isActive;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.workDays,
    this.gracePeriodMinutes = 15,
    this.isActive = true,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'workDays': workDays,
      'gracePeriodMinutes': gracePeriodMinutes,
      'isActive': isActive,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map, String id) {
    return ShiftModel(
      id: id,
      name: map['name'] ?? '',
      startTime: map['startTime'] ?? '08:00',
      endTime: map['endTime'] ?? '17:00',
      workDays: List<int>.from(map['workDays'] ?? [1, 2, 3, 4, 5]),
      gracePeriodMinutes: map['gracePeriodMinutes'] ?? 15,
      isActive: map['isActive'] ?? true,
      description: map['description'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  String get workDaysString {
    const dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return workDays.map((day) => dayNames[day]).join(', ');
  }

  Duration get duration {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    return end.difference(start);
  }

  DateTime _parseTime(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  bool isWorkDay(DateTime date) {
    return workDays.contains(date.weekday);
  }

  ShiftModel copyWith({
    String? name,
    String? startTime,
    String? endTime,
    List<int>? workDays,
    int? gracePeriodMinutes,
    bool? isActive,
    String? description,
  }) {
    return ShiftModel(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      workDays: workDays ?? this.workDays,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
