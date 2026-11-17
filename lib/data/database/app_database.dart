import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/password_hasher.dart';

/// Owns the SQLite connection, the schema and its versioned migrations.
///
/// To change the schema later: bump [schemaVersion] and add the next entry to
/// [_migrations]. `onUpgrade` replays only the missing steps, so existing data
/// is preserved.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const schemaVersion = 1;
  static const fileName = 'stockqr.db';

  /// Opens the database at [path] (defaults to the app support directory).
  /// Pass [inMemoryDatabasePath] in tests.
  static Future<AppDatabase> open({
    String? path,
    PasswordHasher hasher = const PasswordHasher(),
  }) async {
    final resolved = path ?? await _defaultPath();
    final db = await openDatabase(
      resolved,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (var v = 1; v <= version; v++) {
          await _migrations[v]!(db);
        }
        await _seedAdmin(db, hasher);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          await _migrations[v]!(db);
        }
      },
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();

  static Future<String> _defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    return p.join(dir.path, fileName);
  }

  static final Map<int, Future<void> Function(Database)> _migrations = {
    1: _migrationV1,
  };

  // ---------------------------------------------------------------- schema v1

  static Future<void> _migrationV1(Database db) async {
    // Dates are stored as UTC ISO-8601 text so they sort and compare correctly.
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL
      )''');

    await db.execute('''
      CREATE TABLE user_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE
          REFERENCES users(id) ON DELETE CASCADE,
        can_scan INTEGER NOT NULL DEFAULT 1 CHECK (can_scan IN (0, 1)),
        max_products INTEGER NOT NULL DEFAULT 50 CHECK (max_products >= 0),
        subscription_start TEXT NOT NULL,
        subscription_end TEXT
      )''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        sku TEXT NOT NULL,
        barcode TEXT,
        qr_identifier TEXT NOT NULL UNIQUE,
        description TEXT,
        category TEXT NOT NULL DEFAULT 'Général',
        purchase_price REAL NOT NULL DEFAULT 0 CHECK (purchase_price >= 0),
        selling_price REAL NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
        quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
        min_stock_threshold INTEGER NOT NULL DEFAULT 0
          CHECK (min_stock_threshold >= 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    // A SKU is unique inside one user's inventory, case-insensitively.
    await db.execute(
      'CREATE UNIQUE INDEX idx_products_user_sku '
      'ON products(user_id, sku COLLATE NOCASE)',
    );
    await db.execute('CREATE INDEX idx_products_user ON products(user_id)');
    await db.execute(
      'CREATE INDEX idx_products_user_category ON products(user_id, category)',
    );

    // --- Prepared for Part 2 (stock movements, sales, alerts) ---------------

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        movement_type TEXT NOT NULL
          CHECK (movement_type IN ('in', 'out', 'adjustment')),
        quantity INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT
      )''');
    await db.execute(
      'CREATE INDEX idx_movements_user_date ON stock_movements(user_id, date)',
    );
    await db.execute(
      'CREATE INDEX idx_movements_product ON stock_movements(product_id)',
    );

    // product_id is nullable with SET NULL so that deleting a product never
    // erases the revenue already earned from it.
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        unit_price REAL NOT NULL CHECK (unit_price >= 0),
        total_amount REAL NOT NULL CHECK (total_amount >= 0),
        status TEXT NOT NULL DEFAULT 'completed'
          CHECK (status IN ('completed', 'cancelled')),
        date TEXT NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_sales_user_date ON sales(user_id, date)');

    await db.execute('''
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
        message TEXT NOT NULL,
        alert_type TEXT NOT NULL
          CHECK (alert_type IN ('low_stock', 'out_of_stock', 'info')),
        is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
        created_at TEXT NOT NULL
      )''');
    await db.execute(
      'CREATE INDEX idx_alerts_user_read ON alerts(user_id, is_read)',
    );
  }

  /// Creates the default administrator. Only the salted hash is stored.
  static Future<void> _seedAdmin(Database db, PasswordHasher hasher) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final adminId = await db.insert('users', {
      'full_name': AppConstants.defaultAdminName,
      'username': AppConstants.defaultAdminUsername,
      'email': AppConstants.defaultAdminEmail,
      'password_hash': hasher.hash(AppConstants.defaultAdminPassword),
      'role': 'admin',
      'is_active': 1,
      'created_at': now,
    });
    // Admin limits are ignored by the business logic; this row only keeps the
    // data model uniform (every user has exactly one permissions row).
    await db.insert('user_permissions', {
      'user_id': adminId,
      'can_scan': 1,
      'max_products': 1000000,
      'subscription_start': now,
      'subscription_end': null,
    });
  }
}
