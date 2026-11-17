import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'data/database/app_database.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/stats_repository.dart';
import 'data/repositories/user_repository.dart';
import 'providers/auth_provider.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/product_service.dart';
import 'services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite uses the platform plugin on Android/iOS; desktop needs FFI.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await initializeDateFormatting(AppConstants.locale);

  final database = await AppDatabase.open();

  // Composition root: build repositories and services once.
  final users = UserRepository(database);
  final products = ProductRepository(database);
  final stats = StatsRepository(database);
  final auth = AuthProvider(
    auth: AuthService(users: users, session: const SessionStore()),
    users: users,
  );
  // Resume a stored session before the first frame decides what to show.
  await auth.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        Provider<ProductRepository>.value(value: products),
        Provider<StatsRepository>.value(value: stats),
        Provider<ProductService>.value(
          value: ProductService(products: products, users: users),
        ),
        Provider<AdminService>.value(
          value: AdminService(users: users, stats: stats),
        ),
      ],
      child: const StockQrApp(),
    ),
  );
}
