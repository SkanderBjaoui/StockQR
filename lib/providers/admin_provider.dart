import 'package:flutter/foundation.dart';

import '../data/models/app_user.dart';
import '../data/models/stats.dart';
import '../services/admin_service.dart';

/// State of the administration section (global figures + account list).
class AdminProvider extends ChangeNotifier {
  AdminProvider({required this.adminId, required AdminService service})
      : _service = service;

  final int adminId;
  final AdminService _service;

  AdminStats? _stats;
  List<AppUser> _users = const [];
  String _query = '';
  bool _loading = true;
  bool _disposed = false;

  AdminStats? get stats => _stats;
  List<AppUser> get users => _users;
  String get query => _query;
  bool get isLoading => _loading;

  Future<void> load() async {
    try {
      _stats = await _service.globalStats(adminId);
      _users = await _service.listUsers(adminId, query: _query);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> search(String value) {
    _query = value.trim();
    return load();
  }

  Future<UserDetail> detail(int userId) => _service.detail(adminId, userId);

  Future<void> setActive(int userId, bool active) async {
    await _service.setActive(adminId, userId, active);
    await load();
  }

  Future<void> updatePermissions(
    int userId, {
    required bool canScan,
    required int maxProducts,
    DateTime? subscriptionEnd,
  }) async {
    await _service.updatePermissions(
      adminId,
      userId,
      canScan: canScan,
      maxProducts: maxProducts,
      subscriptionEnd: subscriptionEnd,
    );
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
