class UserModel {
  final String uid;
  final String name;
  final String? email; // Made email optional
  final String role; // 'manager' or 'worker'

  UserModel({
    required this.uid,
    required this.name,
    this.email, // Added email to constructor
    required this.role,
  });

  // Modified fromMap to accept uid separately and read email from map
  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid, // Use the passed uid
      name: data['name'] as String,
      email: data['email'] as String?, // Read email from map
      role: data['role'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email, // Added email to map
      'role': role,
    };
  }
}
