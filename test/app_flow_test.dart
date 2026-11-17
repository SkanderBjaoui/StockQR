import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventory_app/app.dart';
import 'package:inventory_app/core/constants/app_constants.dart';
import 'package:inventory_app/data/repositories/product_repository.dart';
import 'package:inventory_app/data/repositories/stats_repository.dart';
import 'package:inventory_app/providers/auth_provider.dart';
import 'package:inventory_app/services/admin_service.dart';
import 'package:inventory_app/services/product_service.dart';
import 'package:provider/provider.dart';

import 'helpers/test_env.dart';

/// End-to-end UI tests over a real (in-memory) SQLite database.
void main() {
  late TestEnv env;

  setUpAll(() async => initializeDateFormatting(AppConstants.locale));

  // Real DB I/O is not driven by the fake clock of testWidgets, so each wait
  // lets real time pass, then pumps the resulting frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Boots the app exactly like main(): restore the session, then run.
  Future<void> launchApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = AuthProvider(
      auth: env.auth,
      users: env.users,
      clock: () => env.now,
    );
    await tester.runAsync(auth.restoreSession);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          Provider<ProductRepository>.value(value: env.products),
          Provider<StatsRepository>.value(value: env.stats),
          Provider<ProductService>.value(value: env.productService),
          Provider<AdminService>.value(value: env.adminService),
        ],
        child: const StockQrApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> signIn(WidgetTester tester, String user, String pass) async {
    await tester.enterText(find.byType(TextFormField).at(0), user);
    await tester.enterText(find.byType(TextFormField).at(1), pass);
    await tester.tap(find.text('Se connecter'));
    await settle(tester);
  }

  setUp(() async {
    await initializeDateFormatting(AppConstants.locale);
    env = await TestEnv.create();
  });

  tearDown(() async => env.close());

  testWidgets('login validates input and rejects wrong credentials',
      (tester) async {
    await launchApp(tester);
    expect(find.text('Connexion'), findsOneWidget);

    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(find.text("L'identifiant est obligatoire."), findsOneWidget);
    expect(find.text('Le mot de passe est obligatoire.'), findsOneWidget);

    await signIn(tester, 'admin', 'wrong-password');
    expect(find.text('Identifiant ou mot de passe incorrect.'), findsOneWidget);
    expect(find.textContaining('Bonjour'), findsNothing);
  });

  testWidgets('the default admin signs in and sees the Administration tab',
      (tester) async {
    await launchApp(tester);
    await signIn(tester, 'admin', 'Admin@123');

    expect(find.text('Bonjour, Administrateur'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget); // extra nav item
  });

  testWidgets('a regular user has no Administration tab', (tester) async {
    await tester.runAsync(() => env.register('alice'));
    await launchApp(tester);
    await signIn(tester, 'alice', 'Password1');

    expect(find.text('Bonjour, User alice'), findsOneWidget);
    expect(find.text('Admin'), findsNothing);
    // Empty state with a clear call to action.
    expect(find.text('Aucun produit pour le moment'), findsOneWidget);
  });

  testWidgets('registration creates the account and signs it in',
      (tester) async {
    await launchApp(tester);
    await tester.tap(find.text('Créer un compte'));
    await settle(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sarra Ben Ali');
    await tester.enterText(fields.at(1), 'sarra');
    await tester.enterText(fields.at(2), 'sarra@example.com');
    await tester.enterText(fields.at(3), 'Secret123');
    await tester.enterText(fields.at(4), 'Different1');
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);

    await tester.enterText(fields.at(4), 'Secret123');
    await tester.tap(find.text('Créer mon compte'));
    await settle(tester);

    expect(find.text('Bonjour, Sarra Ben Ali'), findsOneWidget);
  });

  testWidgets('creating a product updates the dashboard figures',
      (tester) async {
    await tester.runAsync(() => env.register('alice'));
    await launchApp(tester);
    await signIn(tester, 'alice', 'Password1');

    await tester.tap(find.text('Nouveau produit').first);
    await settle(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Huile d’olive');
    await tester.enterText(fields.at(1), 'HUI-01');
    await tester.enterText(fields.at(5), '10,5'); // purchase (after barcode, category, description)
    await tester.enterText(fields.at(6), '15'); // selling
    await tester.enterText(fields.at(7), '8'); // quantity
    await tester.ensureVisible(find.text('Créer le produit'));
    await tester.tap(find.text('Créer le produit'));
    await settle(tester);

    // Back on the dashboard: the product and the derived figures are there.
    expect(find.text('Huile d’olive'), findsOneWidget);
    expect(find.textContaining('84,000'), findsOneWidget); // 8 x 10.5 stock value
    expect(find.textContaining('120,000'), findsOneWidget); // 8 x 15 potential
    expect(find.text('Aucun produit pour le moment'), findsNothing);
  });

  testWidgets('the session survives an app restart, logout ends it',
      (tester) async {
    await tester.runAsync(() => env.register('alice'));
    await launchApp(tester);
    await signIn(tester, 'alice', 'Password1');
    expect(find.text('Bonjour, User alice'), findsOneWidget);

    // "Restart": tear the widget tree down and boot a fresh app.
    await tester.pumpWidget(const SizedBox());
    await launchApp(tester);
    expect(find.text('Bonjour, User alice'), findsOneWidget,
        reason: 'no login screen after restart');

    // Sign out from the profile tab.
    await tester.tap(find.text('Profil'));
    await settle(tester);
    await tester.ensureVisible(find.text('Se déconnecter'));
    await tester.tap(find.text('Se déconnecter').first);
    await settle(tester);
    await tester.tap(find.text('Se déconnecter').last); // confirm dialog
    await settle(tester);
    expect(find.text('Connexion'), findsOneWidget);

    // Restarting now lands on the login screen.
    await tester.pumpWidget(const SizedBox());
    await launchApp(tester);
    expect(find.text('Connexion'), findsOneWidget);
  });
}
