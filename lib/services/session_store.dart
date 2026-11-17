import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Persists which user is signed in, so the session survives an app restart.
/// Only the user id is stored: no password, no hash.
class SessionStore {
  const SessionStore();

  Future<int?> readUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.sessionKey);
  }

  Future<void> saveUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.sessionKey, id);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.sessionKey);
  }
}
