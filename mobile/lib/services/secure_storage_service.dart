import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT access/refresh token pair and the last-known user
/// profile across app restarts, in the platform keystore/keychain rather
/// than plaintext shared_preferences.
class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _accessKey = 'securecity_access_token';
  static const _refreshKey = 'securecity_refresh_token';
  static const _userKey = 'securecity_user';

  static Future<String?> getAccessToken() => _storage.read(key: _accessKey);

  static Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _userKey, value: jsonEncode(user));
  }

  /// Updates just the token pair (e.g. after a silent refresh) without
  /// touching the cached user profile.
  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}
