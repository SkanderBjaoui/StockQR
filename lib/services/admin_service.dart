import '../core/errors/app_exception.dart';
import '../data/models/app_user.dart';
import '../data/models/stats.dart';
import '../data/models/user_permissions.dart';
import '../data/repositories/stats_repository.dart';
import '../data/repositories/user_repository.dart';

/// Everything a user-management screen needs about one account.
class UserDetail {
  const UserDetail({
    required this.user,
    required this.permissions,
    required this.stats,
  });
  final AppUser user;
  final UserPermissions permissions;
  final DashboardStats stats;
}

/// Administration use cases. Every method first checks, against the database,
/// that the caller really is an administrator.
class AdminService {
  AdminService({
    required UserRepository users,
    required StatsRepository stats,
    DateTime Function()? clock,
  })  : _users = users,
        _stats = stats,
        _clock = clock ?? DateTime.now;

  final UserRepository _users;
  final StatsRepository _stats;
  final DateTime Function() _clock;

  Future<AdminStats> globalStats(int actorId) async {
    await _requireAdmin(actorId);
    return _stats.global(now: _clock());
  }

  Future<List<AppUser>> listUsers(int actorId, {String query = ''}) async {
    await _requireAdmin(actorId);
    return _users.listRegularUsers(query: query);
  }

  Future<UserDetail> detail(int actorId, int userId) async {
    await _requireAdmin(actorId);
    final user = await _users.findById(userId);
    final perms = await _users.permissionsOf(userId);
    if (user == null || perms == null) {
      throw const NotFoundException('Compte introuvable.');
    }
    return UserDetail(
      user: user,
      permissions: perms,
      stats: await _stats.forUser(userId, now: _clock()),
    );
  }

  /// Activates or deactivates an account. Data is never deleted.
  Future<void> setActive(int actorId, int userId, bool active) async {
    await _requireAdmin(actorId);
    final target = await _users.findById(userId);
    if (target == null) throw const NotFoundException('Compte introuvable.');
    if (target.isAdmin) {
      throw const PermissionDeniedException(
        "Le compte administrateur ne peut pas être désactivé.",
      );
    }
    await _users.setActive(userId, active);
  }

  Future<void> updatePermissions(
    int actorId,
    int userId, {
    required bool canScan,
    required int maxProducts,
    DateTime? subscriptionEnd,
  }) async {
    await _requireAdmin(actorId);
    if (maxProducts < 0) {
      throw const ValidationException(
        'Le nombre maximum de produits ne peut pas être négatif.',
      );
    }
    final current = await _users.permissionsOf(userId);
    if (current == null) throw const NotFoundException('Compte introuvable.');
    if (subscriptionEnd != null &&
        subscriptionEnd.isBefore(current.subscriptionStart)) {
      throw const ValidationException(
        "La fin d'abonnement doit être postérieure à son début.",
      );
    }
    await _users.savePermissions(
      current.copyWith(
        canScan: canScan,
        maxProducts: maxProducts,
        subscriptionEnd: subscriptionEnd,
        clearSubscriptionEnd: subscriptionEnd == null,
      ),
    );
  }

  Future<void> _requireAdmin(int actorId) async {
    final actor = await _users.findById(actorId);
    if (actor == null || !actor.isAdmin || !actor.isActive) {
      throw const PermissionDeniedException(
        'Action réservée à l\'administrateur.',
      );
    }
  }
}
