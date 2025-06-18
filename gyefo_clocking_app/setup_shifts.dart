import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gyefo_clocking_app/models/shift_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

/// Script to create sample shift data in Firestore
/// Run this once to populate the shifts collection with default shifts
Future<void> createSampleShifts() async {
  try {
    await Firebase.initializeApp();
    final firestore = FirebaseFirestore.instance;

    // Standard Day Shift - 08:00 to 17:00, no overtime, no weekends, 10 min grace
    final standardDayShift = ShiftModel(
      id: 'standard_day',
      name: 'Standard Day Shift',
      startTime: '08:00',
      endTime: '17:00',
      workDays: [1, 2, 3, 4, 5], // Monday to Friday
      gracePeriodMinutes: 10,
      allowOvertime: false,
      allowWeekends: false,
      isActive: true,
      description: 'Regular 9-hour day shift for office workers',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Flexible Day Shift - 08:00 to 17:00, overtime allowed, weekends allowed, 15 min grace
    final flexibleDayShift = ShiftModel(
      id: 'flexible_day',
      name: 'Flexible Day Shift',
      startTime: '08:00',
      endTime: '17:00',
      workDays: [1, 2, 3, 4, 5, 6, 7], // All days
      gracePeriodMinutes: 15,
      allowOvertime: true,
      allowWeekends: true,
      isActive: true,
      description: 'Flexible shift with overtime and weekend work allowed',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Night Shift - 22:00 to 06:00, overtime allowed, weekends allowed, 15 min grace
    final nightShift = ShiftModel(
      id: 'night_shift',
      name: 'Night Shift',
      startTime: '22:00',
      endTime: '06:00',
      workDays: [1, 2, 3, 4, 5], // Monday to Friday
      gracePeriodMinutes: 15,
      allowOvertime: true,
      allowWeekends: false,
      isActive: true,
      description: 'Night shift for 24/7 operations',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Part-time Shift - 13:00 to 17:00, no overtime, weekends allowed, 5 min grace
    final partTimeShift = ShiftModel(
      id: 'part_time',
      name: 'Part-time Afternoon',
      startTime: '13:00',
      endTime: '17:00',
      workDays: [1, 2, 3, 4, 5, 6], // Monday to Saturday
      gracePeriodMinutes: 5,
      allowOvertime: false,
      allowWeekends: true,
      isActive: true,
      description: 'Part-time afternoon shift for flexible workers',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Add shifts to Firestore
    final shifts = [
      standardDayShift,
      flexibleDayShift,
      nightShift,
      partTimeShift,
    ];
    for (final shift in shifts) {
      await firestore.collection('shifts').doc(shift.id).set(shift.toMap());
      AppLogger.success('✅ Created shift: ${shift.name}');
    }

    AppLogger.success('🎉 All sample shifts created successfully!');
  } catch (e) {
    AppLogger.error('❌ Error creating sample shifts: $e');
  }
}

/// Call this function to create sample shifts
/// This would typically be run from a separate script or admin interface
void main() async {
  await createSampleShifts();
}
