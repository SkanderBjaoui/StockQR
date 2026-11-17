import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../database/app_database.dart';
import '../models/app_user.dart';
import '../models/user_permissions.dart';

/// A user row plus the hash needed to verify a login attempt.
class UserCredentials {
  const UserCredentials(this.user, this.passwordHash);
  final AppUser user;
  final String passwordHash;
}

class UserRepository {
  UserRepository(this._database);

  final AppDatabase _database;
  Database get _db => _database.db;

  /// Inserts the user and its permissions row atomically.
  Future<AppUser> create({
    required String fullName,
    required String username,
    required String email,
    required String passwordHash,
    required UserRole role,
    required UserPermissions Function(int userId) permissionsFor,
  }) async {
    try {
      return await _db.transaction((txn) async {
        final now = DateTime.now().toUtc().toIso8601String();
        final id = await txn.insert('users', {
          'full_name': fullName,
          'username': username,
          'email': email,
          'password_hash': passwordHash,
          'role': role.dbValue,
          'is_active': 1,
          'created_at': now,
        });
        final perms = permissionsFor(id);
        await txn.insert('user_permissions', {
          'user_id': id,
          'can_scan': perms.canScan ? 1 : 0,
          'max_products': perms.maxProducts,
          'subscription_start':
              perms.subscriptionStart.toUtc().toIso8601String(),
          'subscription_end': perms.subscriptionEnd?.toUtc().toIso8601String(),
        });
        final rows = await txn.query('users', where: 'id = ?', whereArgs: [id]);
        return AppUser.fromMap(rows.single);
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        final text = e.toString();
        if (text.contains('users.email')) {
          throw const DuplicateException(
            'Cette adresse e-mail est déjà utilisée.',
            field: 'email',
          );
        }
        throw const DuplicateException(
          "Ce nom d'utilisateur est déjà pris.",
          field: 'username',
        );
      }
      throw const StorageException();
    }
  }

  Future<bool> usernameExists(String username) async => _exists(
        'username',
        username,
      );

  Future<bool> emailExists(String email) async => _exists('email', email);

  Future<bool> _exists(String column, String value) async {
    // Columns are COLLATE NOCASE, so equality is case-insensitive.
    final rows = await _db.query(
      'users',
      columns: ['id'],
      where: '$column = ?',
      whereArgs: [value],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Finds a user by username or e-mail (case-insensitive).
  Future<UserCredentials?> findForLogin(String identifier) async {
    final rows = await _db.query(
      'users',
      where: 'username = ? OR email = ?',
      whereArgs: [identifier, identifier],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserCredentials(
      AppUser.fromMap(rows.single),
      rows.single['password_hash']! as String,
    );
  }

  Future<AppUser?> findById(int id) async {
    final rows =
        await _db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.single);
  }

  Future<String?> passwordHashOf(int userId) async {
    final rows = await _db.query(
      'users',
      columns: ['password_hash'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['password_hash']! as String;
  }

  Future<void> updatePasswordHash(int userId, String hash) async {
    await _db.update(
      'users',
      {'password_hash': hash},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<UserPermissions?> permissionsOf(int userId) async {
    final rows = await _db.query(
      'user_permissions',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : UserPermissions.fromMap(rows.single);
  }

  Future<void> savePermissions(UserPermissions perms) async {
    await _db.update(
      'user_permissions',
      {
        'can_scan': perms.canScan ? 1 : 0,
        'max_products': perms.maxProducts,
        'subscription_start':
            perms.subscriptionStart.toUtc().toIso8601String(),
        'subscription_end': perms.subscriptionEnd?.toUtc().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [perms.userId],
    );
  }

  Future<void> setActive(int userId, bool active) async {
    await _db.update(
      'users',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// All regular accounts, newest first, optionally filtered by name,
  /// username or e-mail.
  Future<List<AppUser>> listRegularUsers({String query = ''}) async {
    final term = query.trim();
    final rows = await _db.query(
      'users',
      where: term.isEmpty
          ? "role = 'user'"
          : "role = 'user' AND (full_name LIKE ? ESCAPE '\\' "
              "OR username LIKE ? ESCAPE '\\' OR email LIKE ? ESCAPE '\\')",
      whereArgs: term.isEmpty ? null : List.filled(3, '%${escapeLike(term)}%'),
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(AppUser.fromMap).toList();
  }

  /// Escapes `%`, `_` and `\` so user input is matched literally in LIKE.
  static String escapeLike(String input) => input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
