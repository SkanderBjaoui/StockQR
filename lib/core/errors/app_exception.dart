/// Base class for every error the UI is expected to show to the user.
/// [message] is already written in user-facing French.
class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Invalid input (empty name, negative price, ...).
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// A uniqueness rule was violated (username, email, SKU).
class DuplicateException extends AppException {
  const DuplicateException(super.message, {this.field});
  final String? field;
}

/// Wrong credentials or deactivated account.
class AuthException extends AppException {
  const AuthException(super.message);
}

/// The caller is not allowed to do this (role, subscription, quota, ...).
class PermissionDeniedException extends AppException {
  const PermissionDeniedException(super.message);
}

/// The configured maximum number of products has been reached.
class ProductLimitReachedException extends PermissionDeniedException {
  ProductLimitReachedException(this.limit)
      : super(
          'Vous avez atteint la limite de $limit produits autorisée pour '
          "votre compte. Contactez l'administrateur pour l'augmenter.",
        );
  final int limit;
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Unexpected storage failure, wrapped so the UI never shows raw SQL errors.
class StorageException extends AppException {
  const StorageException([
    super.message = "Une erreur est survenue lors de l'accès aux données.",
  ]);
}
