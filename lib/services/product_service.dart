import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../data/models/app_user.dart';
import '../data/models/product.dart';
import '../data/models/user_permissions.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/user_repository.dart';
import 'permission_service.dart';

/// Product CRUD with business rules: ownership, validation, SKU uniqueness,
/// subscription state and product quota.
///
/// The acting user's account and permissions are re-read from the database on
/// every mutation, so a stale screen cannot bypass a change made by the admin.
class ProductService {
  ProductService({
    required ProductRepository products,
    required UserRepository users,
    PermissionService permissions = const PermissionService(),
    DateTime Function()? clock,
    Uuid uuid = const Uuid(),
  })  : _products = products,
        _users = users,
        _permissions = permissions,
        _clock = clock ?? DateTime.now,
        _uuid = uuid;

  final ProductRepository _products;
  final UserRepository _users;
  final PermissionService _permissions;
  final DateTime Function() _clock;
  final Uuid _uuid;

  // ---- reads (always scoped to the user) ----

  Future<List<Product>> list(
    int userId, {
    String query = '',
    String? category,
    ProductSort sort = ProductSort.name,
    bool ascending = true,
  }) =>
      _products.list(userId,
          query: query, category: category, sort: sort, ascending: ascending);

  Future<Product?> get(int userId, int productId) =>
      _products.getById(userId, productId);

  Future<List<String>> categories(int userId) => _products.categories(userId);

  Future<int> count(int userId) => _products.count(userId);

  // ---- writes ----

  Future<Product> create(int userId, ProductInput input) async {
    final actor = await _actor(userId);
    _permissions.assertCanCreateProduct(
      actor.user,
      actor.permissions,
      await _products.count(userId),
      _clock(),
    );
    final clean = _validate(input);

    final now = _clock();
    final draft = Product(
      userId: userId,
      name: clean.name,
      sku: clean.sku,
      barcode: clean.barcode,
      // Random v4 UUID: unique and independent of any editable field.
      qrIdentifier: _uuid.v4(),
      description: clean.description,
      category: clean.category,
      purchasePrice: clean.purchasePrice,
      sellingPrice: clean.sellingPrice,
      quantity: clean.quantity,
      minStockThreshold: clean.minStockThreshold,
      createdAt: now,
      updatedAt: now,
    );
    // The quota is re-checked atomically inside the insert transaction.
    return _products.insert(
      draft,
      maxProducts: _permissions.productLimitFor(actor.user, actor.permissions),
    );
  }

  Future<Product> update(int userId, int productId, ProductInput input) async {
    final actor = await _actor(userId);
    _permissions.assertCanWrite(actor.user, actor.permissions, _clock());
    final clean = _validate(input);

    final existing = await _products.getById(userId, productId);
    if (existing == null) {
      throw const NotFoundException('Produit introuvable.');
    }
    return _products.update(existing.copyWithInput(clean, _clock()));
  }

  Future<void> delete(int userId, int productId) async {
    final actor = await _actor(userId);
    _permissions.assertCanWrite(actor.user, actor.permissions, _clock());
    await _products.delete(userId, productId);
  }

  // ---- helpers ----

  Future<({AppUser user, UserPermissions permissions})> _actor(
    int userId,
  ) async {
    final user = await _users.findById(userId);
    final perms = await _users.permissionsOf(userId);
    if (user == null || perms == null) {
      throw const NotFoundException('Compte introuvable.');
    }
    return (user: user, permissions: perms);
  }

  ProductInput _validate(ProductInput input) {
    final name = input.name.trim();
    final sku = input.sku.trim();
    final category = input.category.trim();
    if (name.isEmpty) throw const ValidationException('Le nom est obligatoire.');
    if (sku.isEmpty) {
      throw const ValidationException('Le code produit est obligatoire.');
    }
    if (category.isEmpty) {
      throw const ValidationException('La catégorie est obligatoire.');
    }
    if (input.purchasePrice < 0 || input.sellingPrice < 0) {
      throw const ValidationException('Les prix ne peuvent pas être négatifs.');
    }
    if (input.quantity < 0 || input.minStockThreshold < 0) {
      throw const ValidationException(
        'Les quantités ne peuvent pas être négatives.',
      );
    }
    String? blankToNull(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    return ProductInput(
      name: name,
      sku: sku,
      barcode: blankToNull(input.barcode),
      description: blankToNull(input.description),
      category: category,
      purchasePrice: input.purchasePrice,
      sellingPrice: input.sellingPrice,
      quantity: input.quantity,
      minStockThreshold: input.minStockThreshold,
    );
  }
}
