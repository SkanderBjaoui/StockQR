import '../core/errors/app_exception.dart';
import '../data/models/app_user.dart';
import '../data/models/user_permissions.dart';

enum AccessLevel {
  /// Everything allowed (within the configured quotas).
  full,

  /// Subscription expired: data stays visible, but nothing can be changed.
  readOnly,

  /// Account deactivated: cannot sign in. Data is kept untouched.
  blocked,
}

class AccessStatus {
  const AccessStatus(this.level, [this.message]);

  static const full = AccessStatus(AccessLevel.full);

  final AccessLevel level;

  /// User-facing explanation when access is restricted.
  final String? message;

  bool get canWrite => level == AccessLevel.full;
}

/// Pure business rules for roles, quotas and subscriptions.
///
/// Services call these checks before every mutation, so the rules hold even
/// if a screen forgets to hide a button.
class PermissionService {
  const PermissionService();

  AccessStatus evaluate(
    AppUser user,
    UserPermissions permissions,
    DateTime now,
  ) {
    // The administrator is never restricted by quotas or subscriptions.
    if (user.isAdmin) return AccessStatus.full;

    if (!user.isActive) {
      return const AccessStatus(
        AccessLevel.blocked,
        "Votre compte a été désactivé par l'administrateur. "
        'Vos données sont conservées.',
      );
    }
    if (permissions.isExpiredAt(now)) {
      return const AccessStatus(
        AccessLevel.readOnly,
        'Votre abonnement a expiré : vous pouvez consulter vos données, mais '
        "plus les modifier. Contactez l'administrateur pour le renouveler.",
      );
    }
    return AccessStatus.full;
  }

  /// Throws unless the user may create, edit or delete data.
  void assertCanWrite(AppUser user, UserPermissions permissions, DateTime now) {
    final status = evaluate(user, permissions, now);
    if (!status.canWrite) throw PermissionDeniedException(status.message!);
  }

  /// The product quota to enforce, or `null` when unlimited (administrator).
  int? productLimitFor(AppUser user, UserPermissions permissions) =>
      user.isAdmin ? null : permissions.maxProducts;

  void assertCanCreateProduct(
    AppUser user,
    UserPermissions permissions,
    int currentCount,
    DateTime now,
  ) {
    assertCanWrite(user, permissions, now);
    final limit = productLimitFor(user, permissions);
    if (limit != null && currentCount >= limit) {
      throw ProductLimitReachedException(limit);
    }
  }

  /// Gate for the QR/barcode scanner (Part 2 calls this before opening it).
  void assertCanScan(AppUser user, UserPermissions permissions, DateTime now) {
    final status = evaluate(user, permissions, now);
    if (status.level == AccessLevel.blocked) {
      throw PermissionDeniedException(status.message!);
    }
    if (user.isAdmin) return;
    if (!permissions.canScan) {
      throw const PermissionDeniedException(
        "Le scan n'est pas activé pour votre compte. "
        "Contactez l'administrateur.",
      );
    }
    // Scanning changes stock, so it follows the same rule as other writes.
    if (!status.canWrite) throw PermissionDeniedException(status.message!);
  }
}
