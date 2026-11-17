import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/errors/app_exception.dart';
import 'package:inventory_app/services/permission_service.dart';

import 'helpers/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create(now: DateTime(2026, 11, 17)));
  tearDown(() => env.close());

  Future<void> setLimits(
    int userId, {
    bool? canScan,
    int? maxProducts,
    DateTime? end,
    bool clearEnd = false,
  }) async {
    final perms = (await env.users.permissionsOf(userId))!;
    await env.users.savePermissions(perms.copyWith(
      canScan: canScan,
      maxProducts: maxProducts,
      subscriptionEnd: end,
      clearSubscriptionEnd: clearEnd,
    ));
  }

  group('product quota', () {
    test('blocks creation once the maximum is reached', () async {
      final user = await env.register('alice');
      await setLimits(user.id, maxProducts: 2);

      await env.productService.create(user.id, TestEnv.input(sku: 'A'));
      await env.productService.create(user.id, TestEnv.input(sku: 'B'));
      await expectLater(
        env.productService.create(user.id, TestEnv.input(sku: 'C')),
        throwsA(isA<ProductLimitReachedException>()),
      );
      expect(await env.products.count(user.id), 2);
    });

    test('editing and deleting stay possible at the limit', () async {
      final user = await env.register('alice');
      await setLimits(user.id, maxProducts: 1);
      final p = await env.productService.create(user.id, TestEnv.input());
      await env.productService.update(
        user.id,
        p.id!,
        TestEnv.input(name: 'Renamed'),
      );
      await env.productService.delete(user.id, p.id!);
      // A slot is free again.
      await env.productService.create(user.id, TestEnv.input(sku: 'NEW'));
    });

    test('a limit of 0 forbids any product', () async {
      final user = await env.register('alice');
      await setLimits(user.id, maxProducts: 0);
      await expectLater(
        env.productService.create(user.id, TestEnv.input()),
        throwsA(isA<ProductLimitReachedException>()),
      );
    });

    test('the administrator ignores the product limit', () async {
      final admin = await env.admin();
      await setLimits(admin.id, maxProducts: 1);
      await env.productService.create(admin.id, TestEnv.input(sku: 'A'));
      await env.productService.create(admin.id, TestEnv.input(sku: 'B'));
      expect(await env.products.count(admin.id), 2);
    });
  });

  group('expired subscription', () {
    test('keeps data readable but blocks every write, with an explanation',
        () async {
      final user = await env.register('alice');
      final p = await env.productService.create(user.id, TestEnv.input());

      await setLimits(user.id, end: env.now.subtract(const Duration(days: 1)));

      final expectDenied = throwsA(isA<PermissionDeniedException>()
          .having((e) => e.message, 'message', contains('expiré')));
      await expectLater(
        env.productService.create(user.id, TestEnv.input(sku: 'NEW')),
        expectDenied,
      );
      await expectLater(
        env.productService.update(user.id, p.id!, TestEnv.input(name: 'X')),
        expectDenied,
      );
      await expectLater(
        env.productService.delete(user.id, p.id!),
        expectDenied,
      );

      // Reading still works and nothing was deleted.
      expect(await env.productService.list(user.id), hasLength(1));
      expect(await env.productService.get(user.id, p.id!), isNotNull);
    });

    test('renewing the subscription restores write access', () async {
      final user = await env.register('alice');
      await setLimits(user.id, end: env.now.subtract(const Duration(days: 1)));
      await setLimits(user.id, end: env.now.add(const Duration(days: 30)));
      await env.productService.create(user.id, TestEnv.input());
    });

    test('no end date means the subscription never expires', () async {
      final user = await env.register('alice');
      await setLimits(user.id, clearEnd: true);
      env.now = DateTime(2060);
      await env.productService.create(user.id, TestEnv.input());
    });
  });

  group('deactivation', () {
    test('blocks writes immediately and never deletes data', () async {
      final user = await env.register('alice');
      await env.productService.create(user.id, TestEnv.input());

      await env.users.setActive(user.id, false);

      await expectLater(
        env.productService.create(user.id, TestEnv.input(sku: 'NEW')),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(await env.products.count(user.id), 1);

      await env.users.setActive(user.id, true);
      await env.productService.create(user.id, TestEnv.input(sku: 'NEW'));
      expect(await env.products.count(user.id), 2);
    });
  });

  group('scanning permission (gate used by Part 2)', () {
    const service = PermissionService();

    test('is refused when disabled, allowed when enabled', () async {
      final user = await env.register('alice');
      final account = (await env.users.findById(user.id))!;

      await setLimits(user.id, canScan: false);
      var perms = (await env.users.permissionsOf(user.id))!;
      expect(
        () => service.assertCanScan(account, perms, env.now),
        throwsA(isA<PermissionDeniedException>()),
      );

      await setLimits(user.id, canScan: true);
      perms = (await env.users.permissionsOf(user.id))!;
      service.assertCanScan(account, perms, env.now); // does not throw
    });

    test('is refused when the subscription has expired', () async {
      final user = await env.register('alice');
      await setLimits(user.id, end: env.now.subtract(const Duration(days: 1)));
      final account = (await env.users.findById(user.id))!;
      final perms = (await env.users.permissionsOf(user.id))!;
      expect(
        () => service.assertCanScan(account, perms, env.now),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('administration rights', () {
    test('a regular user cannot call admin operations', () async {
      final alice = await env.register('alice');
      final bob = await env.register('bob');

      await expectLater(
        env.adminService.globalStats(alice.id),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        env.adminService.listUsers(alice.id),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        env.adminService.setActive(alice.id, bob.id, false),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        env.adminService.updatePermissions(
          alice.id,
          alice.id,
          canScan: true,
          maxProducts: 9999,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await env.users.findById(bob.id))!.isActive, isTrue);
    });

    test('the admin can deactivate users and edit their permissions', () async {
      final admin = await env.admin();
      final alice = await env.register('alice');

      await env.adminService.setActive(admin.id, alice.id, false);
      expect((await env.users.findById(alice.id))!.isActive, isFalse);

      final end = env.now.add(const Duration(days: 10));
      await env.adminService.updatePermissions(
        admin.id,
        alice.id,
        canScan: false,
        maxProducts: 7,
        subscriptionEnd: end,
      );
      final perms = (await env.users.permissionsOf(alice.id))!;
      expect(perms.canScan, isFalse);
      expect(perms.maxProducts, 7);
      expect(perms.subscriptionEnd!.toUtc(), end.toUtc());
    });

    test('the administrator account itself cannot be deactivated', () async {
      final admin = await env.admin();
      await expectLater(
        env.adminService.setActive(admin.id, admin.id, false),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('rejects a negative product maximum', () async {
      final admin = await env.admin();
      final alice = await env.register('alice');
      await expectLater(
        env.adminService.updatePermissions(
          admin.id,
          alice.id,
          canScan: true,
          maxProducts: -1,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
