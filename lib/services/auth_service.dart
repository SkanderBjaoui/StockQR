import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/password_hasher.dart';
import '../core/utils/validators.dart';
import '../data/models/app_user.dart';
import '../data/models/user_permissions.dart';
import '../data/repositories/user_repository.dart';
import 'session_store.dart';

/// Registration, login, password change and session restore.
/// Contains no UI code; screens only call these methods.
class AuthService {
  AuthService({
    required UserRepository users,
    required SessionStore session,
    PasswordHasher hasher = const PasswordHasher(),
    DateTime Function()? clock,
  })  : _users = users,
        _session = session,
        _hasher = hasher,
        _clock = clock ?? DateTime.now;

  final UserRepository _users;
  final SessionStore _session;
  final PasswordHasher _hasher;
  final DateTime Function() _clock;

  static const _badCredentials = 'Identifiant ou mot de passe incorrect.';

  Future<AppUser> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final error = Validators.fullName(fullName) ??
        Validators.username(username) ??
        Validators.email(email) ??
        Validators.password(password);
    if (error != null) throw ValidationException(error);

    final cleanUsername = username.trim();
    final cleanEmail = email.trim();
    if (await _users.usernameExists(cleanUsername)) {
      throw const DuplicateException(
        "Ce nom d'utilisateur est déjà pris.",
        field: 'username',
      );
    }
    if (await _users.emailExists(cleanEmail)) {
      throw const DuplicateException(
        'Cette adresse e-mail est déjà utilisée.',
        field: 'email',
      );
    }

    final now = _clock();
    return _users.create(
      fullName: fullName.trim(),
      username: cleanUsername,
      email: cleanEmail,
      passwordHash: _hasher.hash(password),
      role: UserRole.user,
      permissionsFor: (userId) => UserPermissions(
        id: 0, // assigned by the database
        userId: userId,
        canScan: AppConstants.defaultCanScan,
        maxProducts: AppConstants.defaultMaxProducts,
        subscriptionStart: now,
        subscriptionEnd:
            now.add(const Duration(days: AppConstants.defaultSubscriptionDays)),
      ),
    );
  }

  /// Verifies the credentials and starts a persistent session.
  Future<AppUser> login(String identifier, String password) async {
    final id = identifier.trim();
    if (id.isEmpty || password.isEmpty) {
      throw const AuthException(_badCredentials);
    }
    final found = await _users.findForLogin(id);
    // Same message for "unknown user" and "wrong password": no user probing.
    if (found == null || !_hasher.verify(password, found.passwordHash)) {
      throw const AuthException(_badCredentials);
    }
    if (!found.user.isActive) {
      throw const AuthException(
        "Ce compte a été désactivé par l'administrateur. "
        'Vos données sont conservées.',
      );
    }
    await _session.saveUserId(found.user.id);
    return found.user;
  }

  /// Returns the user of the stored session, or null (and clears the session)
  /// if there is none, the account vanished or was deactivated.
  Future<AppUser?> restoreSession() async {
    final id = await _session.readUserId();
    if (id == null) return null;
    final user = await _users.findById(id);
    if (user == null || !user.isActive) {
      await _session.clear();
      return null;
    }
    return user;
  }

  Future<void> logout() => _session.clear();

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final error = Validators.password(newPassword);
    if (error != null) throw ValidationException(error);

    final stored = await _users.passwordHashOf(userId);
    if (stored == null) {
      throw const NotFoundException('Compte introuvable.');
    }
    if (!_hasher.verify(currentPassword, stored)) {
      throw const AuthException('Le mot de passe actuel est incorrect.');
    }
    await _users.updatePasswordHash(userId, _hasher.hash(newPassword));
  }
}
