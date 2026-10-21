enum UserRole {
  adviser,
  student;

  static UserRole? fromName(String? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.role,
    this.studentNumber,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final UserRole? role;
  final String? studentNumber;

  AppUser copyWith({
    String? name,
    String? email,
    String? photoUrl,
    UserRole? role,
    String? studentNumber,
  }) => AppUser(
    uid: uid,
    name: name ?? this.name,
    email: email ?? this.email,
    photoUrl: photoUrl ?? this.photoUrl,
    role: role ?? this.role,
    studentNumber: studentNumber ?? this.studentNumber,
  );

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
    'role': role?.name,
    if (studentNumber != null) 'studentNumber': studentNumber,
  };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    uid: m['uid'] as String,
    name: (m['name'] as String?) ?? '',
    email: (m['email'] as String?) ?? '',
    photoUrl: m['photoUrl'] as String?,
    role: UserRole.fromName(m['role'] as String?),
    studentNumber: m['studentNumber'] as String?,
  );
}
