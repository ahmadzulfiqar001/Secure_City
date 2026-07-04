import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'token_store.dart';

class AuthService extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _ready = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get ready => _ready;

  /// Restores a previously persisted session, if any. Call once at app boot.
  Future<void> init() async {
    _user = await TokenStore.getCachedUser();
    _ready = true;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/auth/register', data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      });
      await _persistSession(res.data);
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _persistSession(res.data);
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> logout() async {
    await TokenStore.clear();
    _user = null;
    notifyListeners();
  }

  Future<void> _persistSession(dynamic data) async {
    final token = data['token'] as String;
    final user = Map<String, dynamic>.from(data['user'] as Map);
    await TokenStore.saveSession(token, user);
    _user = user;
    notifyListeners();
  }
}

/// Single app-wide instance — auth needs to be reachable from the login
/// screen onward, before a `HomeScreen` (and its per-tab widget tree) exists.
final authService = AuthService();
