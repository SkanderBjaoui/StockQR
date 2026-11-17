import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/stats.dart';

/// All statistics are computed in SQL from the actual rows.
class StatsRepository {
  StatsRepository(this._database);

  final AppDatabase _database;
  Database get _db => _database.db;

  /// `[start, end)` of the calendar month containing [now], as UTC ISO text
  /// (the format sale dates are stored in).
  static (String, String) monthBounds(DateTime now) {
    final local = now.toLocal();
    final start = DateTime(local.year, local.month);
    final end = DateTime(local.year, local.month + 1); // handles December
    return (start.toUtc().toIso8601String(), end.toUtc().toIso8601String());
  }

  Future<DashboardStats> forUser(int userId, {DateTime? now}) async {
    final (start, end) = monthBounds(now ?? DateTime.now());

    final stock = (await _db.rawQuery('''
      SELECT
        COUNT(*) AS product_count,
        COALESCE(SUM(quantity), 0) AS total_quantity,
        COALESCE(SUM(CASE WHEN quantity > 0 THEN 1 ELSE 0 END), 0) AS in_stock,
        COALESCE(SUM(CASE WHEN quantity = 0 THEN 1 ELSE 0 END), 0) AS out_stock,
        COALESCE(SUM(quantity * purchase_price), 0) AS stock_value,
        COALESCE(SUM(quantity * selling_price), 0) AS potential
      FROM products WHERE user_id = ?''', [userId])).single;

    final income = await _income(userId: userId, start: start, end: end);

    return DashboardStats(
      monthlyIncome: income,
      totalQuantity: stock['total_quantity']! as int,
      inStockCount: stock['in_stock']! as int,
      outOfStockCount: stock['out_stock']! as int,
      stockValue: (stock['stock_value']! as num).toDouble(),
      potentialRevenue: (stock['potential']! as num).toDouble(),
      productCount: stock['product_count']! as int,
    );
  }

  Future<AdminStats> global({DateTime? now}) async {
    final (start, end) = monthBounds(now ?? DateTime.now());

    final users = (await _db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END), 0) AS active,
        COALESCE(SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END), 0) AS inactive
      FROM users WHERE role = 'user' ''')).single;

    final stock = (await _db.rawQuery('''
      SELECT
        COUNT(*) AS product_count,
        COALESCE(SUM(quantity), 0) AS total_quantity,
        COALESCE(SUM(quantity * purchase_price), 0) AS stock_value
      FROM products''')).single;

    final income = await _income(start: start, end: end);

    return AdminStats(
      userCount: users['total']! as int,
      activeUsers: users['active']! as int,
      inactiveUsers: users['inactive']! as int,
      productCount: stock['product_count']! as int,
      totalQuantity: stock['total_quantity']! as int,
      stockValue: (stock['stock_value']! as num).toDouble(),
      monthlyIncome: income,
    );
  }

  Future<double> _income({
    int? userId,
    required String start,
    required String end,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_amount), 0) AS income FROM sales
      WHERE status = 'completed' AND date >= ? AND date < ?
      ${userId == null ? '' : 'AND user_id = ?'}''',
      [start, end, ?userId],
    );
    return (rows.single['income']! as num).toDouble();
  }
}
