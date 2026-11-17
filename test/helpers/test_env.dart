import 'package:inventory_app/core/utils/password_hasher.dart';
import 'package:inventory_app/data/database/app_database.dart';
import 'package:inventory_app/data/models/app_user.dart';
import 'package:inventory_app/data/models/product.dart';
import 'package:inventory_app/data/repositories/product_repository.dart';
import 'package:inventory_app/data/repositories/stats_repository.dart';
import 'package:inventory_app/data/repositories/user_repository.dart';
import 'package:inventory_app/services/admin_service.dart';
import 'package:inventory_app/services/auth_service.dart';
import 'package:inventory_app/services/product_service.dart';
import 'package:inventory_app/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fast hasher so tests that create many accounts stay quick.
const testHasher = PasswordHasher(iterations: 50);

/// A fully wired in-memory application backend.
class TestEnv {
  TestEnv._(this.database, this.clockRef);

  final AppDatabase database;
  final TestClock clockRef;

  late final users = UserRepository(database);
  late final products = ProductRepository(database);
  late final stats = StatsRepository(database);
  late final auth = AuthService(
    users: users,
    session: const SessionStore(),
    hasher: testHasher,
    clock: () => clockRef.now,
  );
  late final productService = ProductService(
    products: products,
    users: users,
    clock: () => clockRef.now,
  );
  late final adminService = AdminService(
    users: users,
    stats: stats,
    clock: () => clockRef.now,
  );

  /// Moves the fake "now" used by every service.
  set now(DateTime value) => clockRef.now = value;
  DateTime get now => clockRef.now;

  static Future<TestEnv> create({DateTime? now}) async {
    if (!_factoryReady) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _factoryReady = true;
    }
    SharedPreferences.setMockInitialValues({});
    final db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      hasher: testHasher,
    );
    return TestEnv._(db, TestClock(now ?? DateTime.now()));
  }

  Future<void> close() => database.close();

  Future<AppUser> register(String username) => auth.register(
        fullName: 'User $username',
        username: username,
        email: '$username@example.com',
        password: 'Password1',
      );

  Future<AppUser> admin() async {
    final found = await users.findForLogin('admin');
    return found!.user;
  }

  static ProductInput input({
    String name = 'Café moulu',
    String sku = 'CAF-001',
    String category = 'Alimentaire',
    double purchase = 4,
    double selling = 6,
    int quantity = 10,
    int threshold = 3,
  }) =>
      ProductInput(
        name: name,
        sku: sku,
        category: category,
        purchasePrice: purchase,
        sellingPrice: selling,
        quantity: quantity,
        minStockThreshold: threshold,
      );

  /// Inserts a sale row directly (the sales workflow itself is Part 2).
  Future<void> insertSale({
    required int userId,
    required int? productId,
    required double total,
    required DateTime date,
    String status = 'completed',
  }) =>
      database.db.insert('sales', {
        'user_id': userId,
        'product_id': productId,
        'quantity': 1,
        'unit_price': total,
        'total_amount': total,
        'status': status,
        'date': date.toUtc().toIso8601String(),
      });
}

bool _factoryReady = false;

class TestClock {
  TestClock(this.now);
  DateTime now;
}
