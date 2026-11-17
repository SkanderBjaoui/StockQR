import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/constants/app_constants.dart';
import 'package:inventory_app/core/errors/app_exception.dart';
import 'package:inventory_app/core/utils/password_hasher.dart';
import 'package:inventory_app/data/models/app_user.dart';
import 'package:inventory_app/services/auth_service.dart';
import 'package:inventory_app/services/session_store.dart';

import 'helpers/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.close());

  group('password hashing', () {
    test('hash is salted, never the plaintext, and verifies', () {
      const hasher = PasswordHasher(iterations: 50);
      final a = hasher.hash('Secret123');
      final b = hasher.hash('Secret123');
      expect(a, isNot(contains('Secret123')));
      expect(a, isNot(b), reason: 'each hash uses its own random salt');
      expect(hasher.verify('Secret123', a), isTrue);
      expect(hasher.verify('secret123', a), isFalse);
      expect(hasher.verify('Secret123', 'garbage'), isFalse);
    });
  });

  group('default administrator', () {
    test('exists with role admin and a hashed password', () async {
      final found = await env.users.findForLogin(AppConstants.defaultAdminUsername);
      expect(found, isNotNull);
      expect(found!.user.role, UserRole.admin);
      expect(found.passwordHash, isNot(AppConstants.defaultAdminPassword));
      expect(found.passwordHash, startsWith('pbkdf2_sha256\$'));
    });

    test('can sign in with admin / Admin@123', () async {
      final user = await env.auth.login('admin', 'Admin@123');
      expect(user.isAdmin, isTrue);
    });

    test('can change the password, and the old one stops working', () async {
      final admin = await env.auth.login('admin', 'Admin@123');
      await env.auth.changePassword(
        userId: admin.id,
        currentPassword: 'Admin@123',
        newPassword: 'NewSecret99',
      );
      await expectLater(
        env.auth.login('admin', 'Admin@123'),
        throwsA(isA<AuthException>()),
      );
      expect((await env.auth.login('admin', 'NewSecret99')).isAdmin, isTrue);
    });

    test('password change requires the correct current password', () async {
      final admin = await env.admin();
      await expectLater(
        env.auth.changePassword(
          userId: admin.id,
          currentPassword: 'wrong',
          newPassword: 'NewSecret99',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('registration', () {
    test('creates a regular active user with default permissions', () async {
      final user = await env.register('alice');
      expect(user.role, UserRole.user);
      expect(user.isActive, isTrue);

      final perms = await env.users.permissionsOf(user.id);
      expect(perms!.maxProducts, AppConstants.defaultMaxProducts);
      expect(perms.canScan, AppConstants.defaultCanScan);
      expect(perms.subscriptionEnd, isNotNull);

      final stored = await env.users.findForLogin('alice');
      expect(stored!.passwordHash, isNot(contains('Password1')));
    });

    test('rejects duplicate usernames and e-mails, case-insensitively', () async {
      await env.register('alice');
      await expectLater(
        env.auth.register(
          fullName: 'Other',
          username: 'ALICE',
          email: 'other@example.com',
          password: 'Password1',
        ),
        throwsA(isA<DuplicateException>()
            .having((e) => e.field, 'field', 'username')),
      );
      await expectLater(
        env.auth.register(
          fullName: 'Other',
          username: 'other',
          email: 'Alice@Example.com',
          password: 'Password1',
        ),
        throwsA(isA<DuplicateException>()
            .having((e) => e.field, 'field', 'email')),
      );
    });

    test('rejects invalid input', () async {
      await expectLater(
        env.auth.register(
          fullName: 'A',
          username: 'ab',
          email: 'nope',
          password: 'short',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('login', () {
    test('works with username or e-mail, wrong password is rejected', () async {
      await env.register('alice');
      expect((await env.auth.login('alice', 'Password1')).username, 'alice');
      expect(
        (await env.auth.login('ALICE@example.com', 'Password1')).username,
        'alice',
      );
      await expectLater(
        env.auth.login('alice', 'WrongPass1'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        env.auth.login('ghost', 'Password1'),
        throwsA(isA<AuthException>()),
      );
    });

    test('a deactivated account cannot sign in', () async {
      final user = await env.register('alice');
      await env.users.setActive(user.id, false);
      await expectLater(
        env.auth.login('alice', 'Password1'),
        throwsA(isA<AuthException>()
            .having((e) => e.message, 'message', contains('désactivé'))),
      );
    });
  });

  group('session persistence', () {
    test('a new AuthService instance (app restart) restores the user', () async {
      final user = await env.register('alice');
      await env.auth.login('alice', 'Password1');

      // Simulates closing and reopening the app: new service, same storage.
      final reopened = AuthService(
        users: env.users,
        session: const SessionStore(),
        hasher: testHasher,
      );
      expect((await reopened.restoreSession())?.id, user.id);
    });

    test('logout clears the stored session', () async {
      await env.register('alice');
      await env.auth.login('alice', 'Password1');
      await env.auth.logout();
      expect(await env.auth.restoreSession(), isNull);
    });

    test('a session of a deactivated account is not restored', () async {
      final user = await env.register('alice');
      await env.auth.login('alice', 'Password1');
      await env.users.setActive(user.id, false);
      expect(await env.auth.restoreSession(), isNull);
      expect(await const SessionStore().readUserId(), isNull);
    });
  });
}
