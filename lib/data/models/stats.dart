/// The six dashboard figures of a single user, computed by SQL aggregates.
class DashboardStats {
  const DashboardStats({
    required this.monthlyIncome,
    required this.totalQuantity,
    required this.inStockCount,
    required this.outOfStockCount,
    required this.stockValue,
    required this.potentialRevenue,
    required this.productCount,
  });

  static const empty = DashboardStats(
    monthlyIncome: 0,
    totalQuantity: 0,
    inStockCount: 0,
    outOfStockCount: 0,
    stockValue: 0,
    potentialRevenue: 0,
    productCount: 0,
  );

  /// Completed sales during the current calendar month.
  final double monthlyIncome;

  /// Sum of the quantities of all products.
  final int totalQuantity;

  /// Products with quantity > 0.
  final int inStockCount;

  /// Products with quantity = 0.
  final int outOfStockCount;

  /// SUM(quantity x purchase price): what the stock cost.
  final double stockValue;

  /// SUM(quantity x selling price): what the stock would earn if sold out.
  final double potentialRevenue;

  final int productCount;
}

/// Global figures across every account, for the administrator.
class AdminStats {
  const AdminStats({
    required this.userCount,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.productCount,
    required this.totalQuantity,
    required this.stockValue,
    required this.monthlyIncome,
  });

  /// Regular (non-admin) accounts.
  final int userCount;
  final int activeUsers;
  final int inactiveUsers;
  final int productCount;
  final int totalQuantity;
  final double stockValue;
  final double monthlyIncome;
}
