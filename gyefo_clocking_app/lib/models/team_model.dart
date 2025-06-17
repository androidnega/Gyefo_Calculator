class TeamModel {
  final String id;
  final String name;
  final String? description;
  final String managerId; // Manager who oversees this team
  final List<String> memberIds; // Worker IDs in this team
  final String? shiftId; // Default shift for this team
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeamModel({
    required this.id,
    required this.name,
    this.description,
    required this.managerId,
    this.memberIds = const [],
    this.shiftId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'managerId': managerId,
      'memberIds': memberIds,
      'shiftId': shiftId,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TeamModel.fromMap(Map<String, dynamic> map, String id) {
    return TeamModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      managerId: map['managerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      shiftId: map['shiftId'],
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  TeamModel copyWith({
    String? name,
    String? description,
    String? managerId,
    List<String>? memberIds,
    String? shiftId,
    bool? isActive,
  }) {
    return TeamModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      managerId: managerId ?? this.managerId,
      memberIds: memberIds ?? this.memberIds,
      shiftId: shiftId ?? this.shiftId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool hasMember(String userId) {
    return memberIds.contains(userId);
  }

  TeamModel addMember(String userId) {
    if (!memberIds.contains(userId)) {
      return copyWith(memberIds: [...memberIds, userId]);
    }
    return this;
  }

  TeamModel removeMember(String userId) {
    if (memberIds.contains(userId)) {
      final newMembers = List<String>.from(memberIds);
      newMembers.remove(userId);
      return copyWith(memberIds: newMembers);
    }
    return this;
  }
}
