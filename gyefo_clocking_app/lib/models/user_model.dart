class UserModel {
  final String uid;
  final String name;
  final String? email;
  final String role; // 'manager' or 'worker'
  final String? teamId; // Team assignment
  final String? shiftId; // Shift assignment
  final bool isActive;
  final String? phoneNumber;
  final String? department;
  final DateTime? joinDate;

  UserModel({
    required this.uid,
    required this.name,
    this.email,
    required this.role,
    this.teamId,
    this.shiftId,
    this.isActive = true,
    this.phoneNumber,
    this.department,
    this.joinDate,
  });
  // Modified fromMap to accept uid separately and read email from map
  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] as String,
      email: data['email'] as String?,
      role: data['role'] as String,
      teamId: data['teamId'] as String?,
      shiftId: data['shiftId'] as String?,
      isActive: data['isActive'] ?? true,
      phoneNumber: data['phoneNumber'] as String?,
      department: data['department'] as String?,
      joinDate:
          data['joinDate'] != null
              ? DateTime.parse(data['joinDate'] as String)
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'teamId': teamId,
      'shiftId': shiftId,
      'isActive': isActive,
      'phoneNumber': phoneNumber,
      'department': department,
      'joinDate': joinDate?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? role,
    String? teamId,
    String? shiftId,
    bool? isActive,
    String? phoneNumber,
    String? department,
    DateTime? joinDate,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      teamId: teamId ?? this.teamId,
      shiftId: shiftId ?? this.shiftId,
      isActive: isActive ?? this.isActive,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      department: department ?? this.department,
      joinDate: joinDate ?? this.joinDate,
    );
  }

  bool get isWorker => role == 'worker';
  bool get isManager => role == 'manager';
}
