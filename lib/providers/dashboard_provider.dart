import 'package:flutter/foundation.dart';

import '../data/models/product.dart';
import '../data/models/stats.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/stats_repository.dart';
import 'product_provider.dart';

/// Dashboard figures and recent products of the signed-in user.
/// Recomputes automatically whenever the product list is mutated.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required this.userId,
    required StatsRepository stats,
    required ProductRepository products,
    required ProductProvider productProvider,
  })  : _stats = stats,
        _products = products,
        _productProvider = productProvider {
    _seenRevision = productProvider.revision;
    productProvider.addListener(_onProductsChanged);
  }

  final int userId;
  final StatsRepository _stats;
  final ProductRepository _products;
  final ProductProvider _productProvider;

  DashboardStats _data = DashboardStats.empty;
  List<Product> _recent = const [];
  bool _loading = true;
  bool _disposed = false;
  late int _seenRevision;

  DashboardStats get stats => _data;
  List<Product> get recent => _recent;
  bool get isLoading => _loading;

  Future<void> load() async {
    try {
      _data = await _stats.forUser(userId);
      _recent = await _products.recent(userId);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _onProductsChanged() {
    // The product provider also notifies on filter changes; only a real
    // mutation (new revision) affects the statistics.
    if (_productProvider.revision != _seenRevision) {
      _seenRevision = _productProvider.revision;
      load();
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _productProvider.removeListener(_onProductsChanged);
    super.dispose();
  }
}
