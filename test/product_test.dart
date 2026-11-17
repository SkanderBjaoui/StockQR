import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/core/errors/app_exception.dart';
import 'package:inventory_app/data/models/product.dart';
import 'package:inventory_app/services/qr_payload.dart';

import 'helpers/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.close());

  group('CRUD', () {
    test('create stores every field and assigns a QR identifier', () async {
      final user = await env.register('alice');
      final p = await env.productService.create(
        user.id,
        const ProductInput(
          name: '  Thé vert ',
          sku: ' THE-1 ',
          barcode: '6190000000012',
          description: 'Boîte de 20',
          category: 'Boissons',
          purchasePrice: 2.5,
          sellingPrice: 4.25,
          quantity: 12,
          minStockThreshold: 4,
        ),
      );
      expect(p.id, isNotNull);
      expect(p.userId, user.id);
      expect(p.name, 'Thé vert');
      expect(p.sku, 'THE-1');
      expect(p.barcode, '6190000000012');
      expect(p.purchasePrice, 2.5);
      expect(p.sellingPrice, 4.25);
      expect(p.quantity, 12);
      expect(p.qrIdentifier, isNotEmpty);
      expect(p.updatedAt.isBefore(p.createdAt), isFalse);
    });

    test('blank optional fields are stored as null', () async {
      final user = await env.register('alice');
      final p = await env.productService.create(
        user.id,
        const ProductInput(
          name: 'X',
          sku: 'X1',
          barcode: '  ',
          description: '',
          category: 'Général',
          purchasePrice: 1,
          sellingPrice: 2,
          quantity: 1,
          minStockThreshold: 0,
        ),
      );
      expect(p.barcode, isNull);
      expect(p.description, isNull);
    });

    test('update changes fields, bumps updated_at, keeps identity', () async {
      final user = await env.register('alice');
      final created = await env.productService.create(user.id, TestEnv.input());
      env.now = env.now.add(const Duration(minutes: 5));

      final updated = await env.productService.update(
        user.id,
        created.id!,
        TestEnv.input(name: 'Café arabica', sku: 'CAF-002', quantity: 99),
      );
      expect(updated.name, 'Café arabica');
      expect(updated.sku, 'CAF-002');
      expect(updated.quantity, 99);
      expect(updated.id, created.id);
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
    });

    test('delete removes the product', () async {
      final user = await env.register('alice');
      final p = await env.productService.create(user.id, TestEnv.input());
      await env.productService.delete(user.id, p.id!);
      expect(await env.productService.get(user.id, p.id!), isNull);
    });

    test('deleting a product keeps the sales already recorded for it', () async {
      final user = await env.register('alice');
      final p = await env.productService.create(user.id, TestEnv.input());
      await env.insertSale(
        userId: user.id,
        productId: p.id,
        total: 50,
        date: DateTime.now(),
      );
      await env.productService.delete(user.id, p.id!);
      final stats = await env.stats.forUser(user.id);
      expect(stats.monthlyIncome, 50);
    });

    test('rejects invalid values', () async {
      final user = await env.register('alice');
      Future<void> create(ProductInput i) =>
          env.productService.create(user.id, i);

      await expectLater(create(TestEnv.input(name: ' ')),
          throwsA(isA<ValidationException>()));
      await expectLater(create(TestEnv.input(sku: '')),
          throwsA(isA<ValidationException>()));
      await expectLater(create(TestEnv.input(purchase: -1)),
          throwsA(isA<ValidationException>()));
      await expectLater(create(TestEnv.input(quantity: -3)),
          throwsA(isA<ValidationException>()));
      expect(await env.products.count(user.id), 0);
    });
  });

  group('SKU uniqueness', () {
    test('is enforced per user, case-insensitively', () async {
      final user = await env.register('alice');
      await env.productService.create(user.id, TestEnv.input(sku: 'ABC'));
      await expectLater(
        env.productService.create(user.id, TestEnv.input(sku: 'abc')),
        throwsA(isA<DuplicateException>()),
      );
    });

    test('two users may use the same SKU', () async {
      final alice = await env.register('alice');
      final bob = await env.register('bob');
      await env.productService.create(alice.id, TestEnv.input(sku: 'ABC'));
      await env.productService.create(bob.id, TestEnv.input(sku: 'ABC'));
    });

    test('editing a product to a taken SKU is refused', () async {
      final user = await env.register('alice');
      await env.productService.create(user.id, TestEnv.input(sku: 'A'));
      final b = await env.productService.create(user.id, TestEnv.input(sku: 'B'));
      await expectLater(
        env.productService.update(user.id, b.id!, TestEnv.input(sku: 'A')),
        throwsA(isA<DuplicateException>()),
      );
    });

    test('saving a product with its own SKU is fine', () async {
      final user = await env.register('alice');
      final p = await env.productService.create(user.id, TestEnv.input(sku: 'A'));
      await env.productService.update(
        user.id,
        p.id!,
        TestEnv.input(sku: 'A', quantity: 1),
      );
    });
  });

  group('data isolation between users', () {
    test('a user only lists, reads, edits and deletes their own products',
        () async {
      final alice = await env.register('alice');
      final bob = await env.register('bob');
      final aliceProduct =
          await env.productService.create(alice.id, TestEnv.input(sku: 'A1'));
      await env.productService.create(bob.id, TestEnv.input(sku: 'B1'));

      expect(
        (await env.productService.list(alice.id)).map((p) => p.sku),
        ['A1'],
      );
      expect(
        (await env.productService.list(bob.id)).map((p) => p.sku),
        ['B1'],
      );

      // Bob targets Alice's product id directly.
      expect(await env.productService.get(bob.id, aliceProduct.id!), isNull);
      await expectLater(
        env.productService.update(
          bob.id,
          aliceProduct.id!,
          TestEnv.input(name: 'Hacked', sku: 'A1'),
        ),
        throwsA(isA<NotFoundException>()),
      );
      await expectLater(
        env.productService.delete(bob.id, aliceProduct.id!),
        throwsA(isA<NotFoundException>()),
      );

      final untouched = (await env.productService.get(alice.id, aliceProduct.id!))!;
      expect(untouched.name, 'Café moulu');
    });

    test('QR lookup is scoped to the owner', () async {
      final alice = await env.register('alice');
      final bob = await env.register('bob');
      final p = await env.productService.create(alice.id, TestEnv.input());
      expect(await env.products.getByQrIdentifier(alice.id, p.qrIdentifier), isNotNull);
      expect(await env.products.getByQrIdentifier(bob.id, p.qrIdentifier), isNull);
    });

    test('categories are per user', () async {
      final alice = await env.register('alice');
      final bob = await env.register('bob');
      await env.productService
          .create(alice.id, TestEnv.input(sku: 'A', category: 'Secret'));
      expect(await env.productService.categories(bob.id), isEmpty);
    });
  });

  group('search, filter, sort', () {
    late int userId;

    setUp(() async {
      userId = (await env.register('alice')).id;
      final items = [
        TestEnv.input(name: 'Banane', sku: 'FR-01', category: 'Fruits', selling: 3, quantity: 5),
        TestEnv.input(name: 'Ananas', sku: 'FR-02', category: 'Fruits', selling: 9, quantity: 0),
        TestEnv.input(name: 'Cahier', sku: 'PA-01', category: 'Papeterie', selling: 2, quantity: 40),
      ];
      for (final i in items) {
        await env.productService.create(userId, i);
      }
    });

    Future<List<String>> names({
      String query = '',
      String? category,
      ProductSort sort = ProductSort.name,
      bool ascending = true,
    }) async =>
        (await env.productService.list(
          userId,
          query: query,
          category: category,
          sort: sort,
          ascending: ascending,
        ))
            .map((p) => p.name)
            .toList();

    test('searches by name or code', () async {
      expect(await names(query: 'ban'), ['Banane']);
      expect(await names(query: 'pa-0'), ['Cahier']);
      expect(await names(query: 'zzz'), isEmpty);
    });

    test('treats % and _ in the search as literal characters', () async {
      expect(await names(query: '%'), isEmpty);
      expect(await names(query: '_'), isEmpty);
    });

    test('filters by category', () async {
      expect(await names(category: 'Fruits'), ['Ananas', 'Banane']);
      expect(await names(category: 'Papeterie'), ['Cahier']);
    });

    test('combines search and category', () async {
      expect(await names(query: 'a', category: 'Papeterie'), ['Cahier']);
    });

    test('sorts by name, quantity and price in both directions', () async {
      expect(await names(), ['Ananas', 'Banane', 'Cahier']);
      expect(await names(ascending: false), ['Cahier', 'Banane', 'Ananas']);
      expect(await names(sort: ProductSort.quantity),
          ['Ananas', 'Banane', 'Cahier']);
      expect(await names(sort: ProductSort.quantity, ascending: false),
          ['Cahier', 'Banane', 'Ananas']);
      expect(await names(sort: ProductSort.price),
          ['Cahier', 'Banane', 'Ananas']);
    });
  });

  group('stock status', () {
    test('is derived from quantity and threshold', () async {
      final user = await env.register('alice');
      Future<StockStatus> statusFor(int quantity, int threshold, String sku) async =>
          (await env.productService.create(
            user.id,
            TestEnv.input(sku: sku, quantity: quantity, threshold: threshold),
          ))
              .status;

      expect(await statusFor(0, 5, 'a'), StockStatus.outOfStock);
      expect(await statusFor(5, 5, 'b'), StockStatus.low);
      expect(await statusFor(6, 5, 'c'), StockStatus.inStock);
    });
  });

  group('QR identifiers', () {
    test('are unique across many products and users', () async {
      final alice = await env.register('alice');
      final bob = await env.register('bob');
      final ids = <String>{};
      for (var i = 0; i < 30; i++) {
        final a = await env.productService.create(alice.id, TestEnv.input(sku: 'A$i'));
        final b = await env.productService.create(bob.id, TestEnv.input(sku: 'A$i'));
        ids..add(a.qrIdentifier)..add(b.qrIdentifier);
      }
      expect(ids, hasLength(60));
    });

    test('are stable when the product is edited', () async {
      final user = await env.register('alice');
      final p = await env.productService.create(user.id, TestEnv.input());
      final edited = await env.productService.update(
        user.id,
        p.id!,
        TestEnv.input(name: 'Other', sku: 'OTHER', quantity: 1),
      );
      expect(edited.qrIdentifier, p.qrIdentifier);
    });

    test('the database refuses a duplicate QR identifier', () async {
      final user = await env.register('alice');
      final p = await env.productService.create(user.id, TestEnv.input());
      final clone = Product(
        userId: user.id,
        name: 'Clone',
        sku: 'CLONE',
        qrIdentifier: p.qrIdentifier,
        category: 'Général',
        purchasePrice: 1,
        sellingPrice: 1,
        quantity: 1,
        minStockThreshold: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await expectLater(env.products.insert(clone), throwsA(isA<AppException>()));
    });

    test('payload is versioned, contains only the identifier and round-trips',
        () async {
      final user = await env.register('alice');
      final p = await env.productService.create(user.id, TestEnv.input());
      final payload = QrPayload.encode(p.qrIdentifier);

      expect(payload, 'stockqr:v1:${p.qrIdentifier}');
      expect(payload, isNot(contains(p.name)));
      expect(payload, isNot(contains(p.sku)));
      expect(QrPayload.decode(payload), p.qrIdentifier);
      expect(QrPayload.decode('https://example.com'), isNull);
      expect(QrPayload.decode('stockqr:v1:'), isNull);
      expect(QrPayload.decode('stockqr:v2:abc'), isNull);
    });
  });
}
