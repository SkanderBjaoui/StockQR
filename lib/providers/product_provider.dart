import 'package:flutter/foundation.dart';

import '../data/models/product.dart';
import '../services/product_service.dart';

/// Product list state for one signed-in user: filters, sorting and mutations.
/// Created per session, so no data can leak from one account to the next.
class ProductProvider extends ChangeNotifier {
  ProductProvider({required this.userId, required ProductService service})
      : _service = service;

  final int userId;
  final ProductService _service;

  List<Product> _products = const [];
  List<String> _categories = const [];
  String _query = '';
  String? _category;
  ProductSort _sort = ProductSort.name;
  bool _ascending = true;
  bool _loading = true;
  bool _disposed = false;
  int _loadToken = 0;
  int _totalCount = 0;

  /// Number of products owned by the user, ignoring filters.
  int get totalCount => _totalCount;

  /// Incremented after every create/update/delete so other providers (the
  /// dashboard) know when to recompute.
  int revision = 0;

  List<Product> get products => _products;
  List<String> get categories => _categories;
  String get query => _query;
  String? get category => _category;
  ProductSort get sort => _sort;
  bool get ascending => _ascending;
  bool get isLoading => _loading;
  bool get hasActiveFilters => _query.isNotEmpty || _category != null;

  Future<void> load() async {
    // Typing in the search box fires many overlapping loads; only the most
    // recent one may publish its result.
    final token = ++_loadToken;
    _loading = true;
    notifyListeners();
    try {
      final categories = await _service.categories(userId);
      final total = await _service.count(userId);
      // A filter on a category that no longer exists would show nothing.
      if (_category != null && !categories.contains(_category)) {
        _category = null;
      }
      final products = await _service.list(
        userId,
        query: _query,
        category: _category,
        sort: _sort,
        ascending: _ascending,
      );
      if (token != _loadToken) return;
      _categories = categories;
      _totalCount = total;
      _products = products;
    } finally {
      if (token == _loadToken) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setQuery(String value) {
    _query = value.trim();
    return load();
  }

  Future<void> setCategory(String? value) {
    _category = value;
    return load();
  }

  Future<void> setSort(ProductSort value) {
    _sort = value;
    return load();
  }

  Future<void> toggleDirection() {
    _ascending = !_ascending;
    return load();
  }

  Future<void> clearFilters() {
    _query = '';
    _category = null;
    return load();
  }

  Future<Product> create(ProductInput input) async {
    final created = await _service.create(userId, input);
    await _afterMutation();
    return created;
  }

  Future<Product> update(int productId, ProductInput input) async {
    final updated = await _service.update(userId, productId, input);
    await _afterMutation();
    return updated;
  }

  Future<void> delete(int productId) async {
    await _service.delete(userId, productId);
    await _afterMutation();
  }

  Future<Product?> byId(int productId) => _service.get(userId, productId);

  Future<void> _afterMutation() async {
    revision++;
    await load();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
