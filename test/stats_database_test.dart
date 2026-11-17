import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/data/database/app_database.dart';
import 'package:inventory_app/data/models/stats.dart';

import 'helpers/test_env.dart';

void main() {
  // Fixed "today" so month boundaries are deterministic.
  final today = DateTime(2026, 11, 17, 12);

  late TestEnv env;

  setUp(() async => env = await TestEnv.create(now: today));
  tearDown(() => env.close());

  group('dashboard statistics', () {
    test('a new user sees zeros, nothing fabricated', () async {
      final user = await env.register('alice');
      final s = await env.stats.forUser(user.id, now: today);
      expect(s.monthlyIncome, 0);
      expect(s.totalQuantity, 0);
      expect(s.inStockCount, 0);
      expect(s.outOfStockCount, 0);
      expect(s.stockValue, 0);
      expect(s.potentialRevenue, 0);
      expect(s.productCount, 0);
    });

    test('all six figures come from the real rows', () async {
      final user = await env.register('alice');
      // qty 10 x buy 4 / sell 6
      await env.productService.create(user.id,
          TestEnv.input(sku: 'A', quantity: 10, purchase: 4, selling: 6));
      // qty 3 x buy 2.5 / sell 5
      await env.productService.create(user.id,
          TestEnv.input(sku: 'B', quantity: 3, purchase: 2.5, selling: 5));
      // out of stock x buy 100 / sell 200 (contributes nothing to values)
      await env.productService.create(user.id,
          TestEnv.input(sku: 'C', quantity: 0, purchase: 100, selling: 200));

      final s = await env.stats.forUser(user.id, now: today);
      expect(s.totalQuantity, 13);
      expect(s.inStockCount, 2);
      expect(s.outOfStockCount, 1);
      expect(s.stockValue, 10 * 4 + 3 * 2.5); // 47.5
      expect(s.potentialRevenue, 10 * 6 + 3 * 5); // 75
      expect(s.productCount, 3);
    });

    test('statistics follow edits and deletions', () async {
      final user = await env.register('alice');
      final p = await env.productService.create(
          user.id, TestEnv.input(quantity: 10, purchase: 1, selling: 2));
      await env.productService.update(user.id, p.id!,
          TestEnv.input(quantity: 0, purchase: 1, selling: 2));
      var s = await env.stats.forUser(user.id, now: today);
      expect((s.inStockCount, s.outOfStockCount), (0, 1));

      await env.productService.delete(user.id, p.id!);
      s = await env.stats.forUser(user.id, now: today);
      expect(s.productCount, 0);
    });

    test('monthly income counts only completed sales of the current month',
        () async {
      final user = await env.register('alice');
      final other = await env.register('bob');
      Future<void> sale(double total, DateTime date,
              {String status = 'completed', int? userId}) =>
          env.insertSale(
            userId: userId ?? user.id,
            productId: null,
            total: total,
            date: date,
            status: status,
          );

      await sale(100, DateTime(2026, 11, 1)); // first instant of the month
      await sale(50, DateTime(2026, 11, 30, 23, 59)); // last day
      await sale(999, DateTime(2026, 10, 31, 23, 59)); // previous month
      await sale(999, DateTime(2026, 12, 1)); // next month
      await sale(999, DateTime(2026, 11, 10), status: 'cancelled');
      await sale(777, DateTime(2026, 11, 10), userId: other.id); // someone else

      final s = await env.stats.forUser(user.id, now: today);
      expect(s.monthlyIncome, 150);
    });

    test('December rolls over to January correctly', () async {
      final user = await env.register('alice');
      await env.insertSale(
          userId: user.id, productId: null, total: 10, date: DateTime(2026, 12, 15));
      await env.insertSale(
          userId: user.id, productId: null, total: 99, date: DateTime(2027, 1, 1));
      final s = await env.stats.forUser(user.id, now: DateTime(2026, 12, 20));
      expect(s.monthlyIncome, 10);
    });
  });

  group('administrator statistics', () {
    test('aggregate every account', () async {
      final admin = await env.admin();
      final alice = await env.register('alice');
      final bob = await env.register('bob');

      await env.productService.create(alice.id,
          TestEnv.input(sku: 'A', quantity: 10, purchase: 2, selling: 3));
      await env.productService.create(bob.id,
          TestEnv.input(sku: 'B', quantity: 5, purchase: 10, selling: 12));
      // Deactivate after the data exists: it must still be counted.
      await env.users.setActive(bob.id, false);
      await env.insertSale(
          userId: alice.id, productId: null, total: 30, date: today);
      await env.insertSale(
          userId: bob.id, productId: null, total: 12, date: today);

      final AdminStats s = await env.adminService.globalStats(admin.id);
      expect(s.userCount, 2, reason: 'regular accounts only');
      expect(s.activeUsers, 1);
      expect(s.inactiveUsers, 1);
      expect(s.productCount, 2);
      expect(s.totalQuantity, 15);
      expect(s.stockValue, 10 * 2 + 5 * 10);
      expect(s.monthlyIncome, 42);
    });

    test('the admin can read a single user\'s statistics', () async {
      final admin = await env.admin();
      final alice = await env.register('alice');
      await env.productService.create(
          alice.id, TestEnv.input(quantity: 4, purchase: 5, selling: 8));
      final detail = await env.adminService.detail(admin.id, alice.id);
      expect(detail.stats.stockValue, 20);
      expect(detail.stats.potentialRevenue, 32);
      expect(detail.user.username, 'alice');
    });

    test('user search matches name, username and e-mail', () async {
      final admin = await env.admin();
      await env.register('alice');
      await env.register('bob');
      Future<List<String>> find(String q) async =>
          (await env.adminService.listUsers(admin.id, query: q))
              .map((u) => u.username)
              .toList();
      expect(await find('ali'), ['alice']);
      expect(await find('bob@example'), ['bob']);
      expect(await find('User bob'), ['bob']);
      expect(await find(''), unorderedEquals(['alice', 'bob']));
    });
  });

  group('database', () {
    test('creates all required tables', () async {
      final rows = await env.database.db
          .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final tables = rows.map((r) => r['name']).toSet();
      expect(
        tables,
        containsAll([
          'users',
          'user_permissions',
          'products',
          'stock_movements',
          'sales',
          'alerts',
        ]),
      );
    });

    test('foreign keys are enforced', () async {
      await expectLater(
        env.database.db.insert('products', {
          'user_id': 9999,
          'name': 'Orphan',
          'sku': 'O',
          'qr_identifier': 'x',
          'category': 'c',
          'created_at': 'now',
          'updated_at': 'now',
        }),
        throwsA(anything),
      );
    });

    test('check constraints reject negative quantities', () async {
      final user = await env.register('alice');
      await expectLater(
        env.database.db.insert('products', {
          'user_id': user.id,
          'name': 'Bad',
          'sku': 'BAD',
          'qr_identifier': 'bad',
          'category': 'c',
          'quantity': -1,
          'created_at': 'now',
          'updated_at': 'now',
        }),
        throwsA(anything),
      );
    });

    test('deleting a user cascades to their rows only', () async {
      final alice = await env.register('alice');
      final bob = await env.register('bob');
      await env.productService.create(alice.id, TestEnv.input(sku: 'A'));
      await env.productService.create(bob.id, TestEnv.input(sku: 'B'));

      await env.database.db.delete('users', where: 'id = ?', whereArgs: [alice.id]);

      expect(await env.products.count(alice.id), 0);
      expect(await env.products.count(bob.id), 1);
      expect(await env.users.permissionsOf(alice.id), isNull);
    });

    test('data and the seeded admin survive closing and reopening the file',
        () async {
      final dir = await Directory.systemTemp.createTemp('stockqr_test_');
      final path = '${dir.path}${Platform.pathSeparator}test.db';
      try {
        var db = await AppDatabase.open(path: path, hasher: testHasher);
        await db.db.insert('users', {
          'full_name': 'Persisted',
          'username': 'persisted',
          'email': 'p@example.com',
          'password_hash': 'x',
          'role': 'user',
          'is_active': 1,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        await db.close();

        db = await AppDatabase.open(path: path, hasher: testHasher);
        final users = await db.db.query('users', orderBy: 'id');
        // Exactly one admin (not re-seeded) plus the persisted user.
        expect(users.map((u) => u['username']), ['admin', 'persisted']);
        await db.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
