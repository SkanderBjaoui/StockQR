import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../database/app_database.dart';
import '../models/product.dart';
import 'user_repository.dart';

/// Data access for products. Every query is scoped by `user_id`, so one
/// user can never read or modify another user's inventory through this class.
class ProductRepository {
  ProductRepository(this._database);

  final AppDatabase _database;
  Database get _db => _database.db;

  Future<List<Product>> list(
    int userId, {
    String query = '',
    String? category,
    ProductSort sort = ProductSort.name,
    bool ascending = true,
  }) async {
    final where = <String>['user_id = ?'];
    final args = <Object?>[userId];

    final term = query.trim();
    if (term.isNotEmpty) {
      where.add(
        "(name LIKE ? ESCAPE '\\' OR sku LIKE ? ESCAPE '\\' "
        "OR barcode LIKE ? ESCAPE '\\')",
      );
      args.addAll(List.filled(3, '%${UserRepository.escapeLike(term)}%'));
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }

    // Column names come from a closed enum, never from user input.
    final column = switch (sort) {
      ProductSort.name => 'name COLLATE NOCASE',
      ProductSort.quantity => 'quantity',
      ProductSort.price => 'selling_price',
    };
    final direction = ascending ? 'ASC' : 'DESC';

    final rows = await _db.query(
      'products',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: '$column $direction, id ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> recent(int userId, {int limit = 5}) async {
    final rows = await _db.query(
      'products',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getById(int userId, int productId) async {
    final rows = await _db.query(
      'products',
      where: 'id = ? AND user_id = ?',
      whereArgs: [productId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.single);
  }

  /// Resolves a scanned QR identifier to the owner's product (used by Part 2).
  Future<Product?> getByQrIdentifier(int userId, String qrIdentifier) async {
    final rows = await _db.query(
      'products',
      where: 'qr_identifier = ? AND user_id = ?',
      whereArgs: [qrIdentifier, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.single);
  }

  Future<int> count(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM products WHERE user_id = ?',
      [userId],
    );
    return (rows.single['c']! as int);
  }

  Future<List<String>> categories(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT category FROM products WHERE user_id = ? '
      'ORDER BY category COLLATE NOCASE',
      [userId],
    );
    return rows.map((r) => r['category']! as String).toList();
  }

  /// Inserts [draft]. When [maxProducts] is non-null the quota is checked
  /// inside the same transaction, so concurrent inserts cannot exceed it.
  Future<Product> insert(Product draft, {int? maxProducts}) async {
    try {
      final id = await _db.transaction((txn) async {
        if (maxProducts != null) {
          final rows = await txn.rawQuery(
            'SELECT COUNT(*) AS c FROM products WHERE user_id = ?',
            [draft.userId],
          );
          if ((rows.single['c']! as int) >= maxProducts) {
            throw ProductLimitReachedException(maxProducts);
          }
        }
        return txn.insert('products', draft.toMap());
      });
      return (await getById(draft.userId, id))!;
    } on DatabaseException catch (e) {
      throw _translate(e, draft.sku);
    }
  }

  Future<Product> update(Product product) async {
    try {
      final changed = await _db.update(
        'products',
        product.toMap()..remove('id'),
        where: 'id = ? AND user_id = ?',
        whereArgs: [product.id, product.userId],
      );
      if (changed == 0) {
        throw const NotFoundException('Produit introuvable.');
      }
      return (await getById(product.userId, product.id!))!;
    } on DatabaseException catch (e) {
      throw _translate(e, product.sku);
    }
  }

  Future<void> delete(int userId, int productId) async {
    final removed = await _db.delete(
      'products',
      where: 'id = ? AND user_id = ?',
      whereArgs: [productId, userId],
    );
    if (removed == 0) throw const NotFoundException('Produit introuvable.');
  }

  Future<bool> skuExists(int userId, String sku, {int? excludeId}) async {
    final rows = await _db.query(
      'products',
      columns: ['id'],
      where: excludeId == null
          ? 'user_id = ? AND sku = ? COLLATE NOCASE'
          : 'user_id = ? AND sku = ? COLLATE NOCASE AND id != ?',
      whereArgs: [userId, sku, ?excludeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  AppException _translate(DatabaseException e, String sku) {
    if (e.isUniqueConstraintError()) {
      return DuplicateException(
        'Le code produit « $sku » existe déjà dans votre inventaire.',
        field: 'sku',
      );
    }
    return const StorageException();
  }
}
