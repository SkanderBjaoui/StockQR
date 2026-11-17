enum UserRole {
  user,
  admin;

  static UserRole fromDb(String value) =>
      value == 'admin' ? UserRole.admin : UserRole.user;

  String get dbValue => name;
  String get label => this == admin ? 'Administrateur' : 'Utilisateur';
}

/// A registered account. The password hash is deliberately not part of this
/// model: it never leaves the repository except for login verification.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String fullName;
  final String username;
  final String email;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  bool get isAdmin => role == UserRole.admin;

  /// First word of the full name, used in greetings.
  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id']! as int,
        fullName: map['full_name']! as String,
        username: map['username']! as String,
        email: map['email']! as String,
        role: UserRole.fromDb(map['role']! as String),
        isActive: (map['is_active']! as int) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
      );
}
