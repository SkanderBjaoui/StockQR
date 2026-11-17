import 'package:flutter/foundation.dart';

import '../data/models/app_user.dart';
import '../data/models/user_permissions.dart';
import '../data/repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';

/// Holds the signed-in user for the whole app and drives the auth gate.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthService auth,
    required UserRepository users,
    PermissionService permissionService = const PermissionService(),
    DateTime Function()? clock,
  })  : _auth = auth,
        _users = users,
        _permissionService = permissionService,
        _clock = clock ?? DateTime.now;

  final AuthService _auth;
  final UserRepository _users;
  final PermissionService _permissionService;
  final DateTime Function() _clock;

  AppUser? _user;
  UserPermissions? _permissions;
  bool _initializing = true;

  AppUser? get user => _user;
  UserPermissions? get permissions => _permissions;
  bool get isAuthenticated => _user != null;
  bool get isInitializing => _initializing;

  AccessStatus get access {
    final user = _user;
    final perms = _permissions;
    if (user == null || perms == null) return AccessStatus.full;
    return _permissionService.evaluate(user, perms, _clock());
  }

  /// Called once at startup: resumes the stored session if still valid.
  Future<void> restoreSession() async {
    _user = await _auth.restoreSession();
    await _loadPermissions();
    _initializing = false;
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _user = await _auth.login(identifier, password);
    await _loadPermissions();
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    await _auth.register(
      fullName: fullName,
      username: username,
      email: email,
      password: password,
    );
    // Sign the new account in right away.
    await login(username, password);
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _permissions = null;
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) => _auth
      .changePassword(
        userId: _user!.id,
        currentPassword: current,
        newPassword: next,
      );

  /// Re-reads the account and permissions (they may have been edited by the
  /// administrator since sign-in).
  Future<void> refresh() async {
    final id = _user?.id;
    if (id == null) return;
    final fresh = await _users.findById(id);
    if (fresh == null || !fresh.isActive) {
      await logout();
      return;
    }
    _user = fresh;
    await _loadPermissions();
    notifyListeners();
  }

  Future<void> _loadPermissions() async {
    final user = _user;
    _permissions = user == null ? null : await _users.permissionsOf(user.id);
  }
}
