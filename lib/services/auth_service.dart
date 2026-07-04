import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../screens/auth/login_screen.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Returned by [AuthService.register] — registration no longer logs the
/// user in directly, it just creates the (unverified) account and leaves it
/// to the caller to show the OTP screen.
class RegisterResult {
  final String email;
  final String otpDebug;
  RegisterResult(this.email, this.otpDebug);
}

class AuthService extends ChangeNotifier {
  AuthService() {
    ApiClient.instance.tokenProvider = () => _token;
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
  }

  Map<String, dynamic>? _user;
  String? _token;
  bool _ready = false;
  bool _handlingUnauthorized = false;

  /// Whether the session should survive an app restart. Defaults to true;
  /// the login screen's "Remember Me" checkbox flips this before calling
  /// [login].
  bool rememberMe = true;

  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get ready => _ready;

  /// Restores a previously persisted session, if any. Call once at app boot.
  Future<void> init() async {
    _token = await TokenStore.getToken();
    _user = await TokenStore.getCachedUser();
    _ready = true;
    notifyListeners();
  }

  Future<RegisterResult> register({
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
      return RegisterResult(email, res.data['otp_debug'] as String);
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> verifyOtp({required String email, required String code}) async {
    try {
      final res = await ApiClient.instance.dio
          .post('/api/auth/verify-otp', data: {'email': email, 'code': code});
      await _persistSession(res.data);
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<String> resendOtp({required String email}) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/auth/resend-otp', data: {'email': email});
      return res.data['otp_debug'] as String;
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

  Future<String> forgotPassword({required String email}) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/auth/forgot-password', data: {'email': email});
      return res.data['otp_debug'] as String;
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await ApiClient.instance.dio.post('/api/auth/reset-password',
          data: {'email': email, 'code': code, 'new_password': newPassword});
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    try {
      final res =
          await ApiClient.instance.dio.put('/api/auth/me', data: {'name': name, 'phone': phone});
      _user = Map<String, dynamic>.from(res.data as Map);
      if (rememberMe) await TokenStore.saveSession(_token!, _user!);
      notifyListeners();
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> changePassword({required String current, required String newPassword}) async {
    try {
      await ApiClient.instance.dio.post('/api/auth/change-password',
          data: {'current_password': current, 'new_password': newPassword});
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await ApiClient.instance.dio.delete('/api/auth/me');
      await logout();
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> logout() async {
    await TokenStore.clear();
    _token = null;
    _user = null;
    notifyListeners();
  }

  Future<void> _persistSession(dynamic data) async {
    _token = data['token'] as String;
    _user = Map<String, dynamic>.from(data['user'] as Map);
    if (rememberMe) {
      await TokenStore.saveSession(_token!, _user!);
    } else {
      await TokenStore.clear();
    }
    notifyListeners();
  }

  /// Called by [ApiClient] when a request that carried a token comes back
  /// 401 — the token expired or was revoked server-side. Logs out and bounces
  /// to the login screen from wherever the user currently is.
  void _handleUnauthorized() {
    if (_handlingUnauthorized || _token == null) return;
    _handlingUnauthorized = true;
    logout().then((_) {
      final nav = rootNavigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        ScaffoldMessenger.of(nav.context).showSnackBar(
          const SnackBar(content: Text('Your session expired. Please sign in again.')),
        );
      }
      _handlingUnauthorized = false;
    });
  }
}

/// Single app-wide instance — auth needs to be reachable from the login
/// screen onward, before a `HomeScreen` (and its per-tab widget tree) exists.
final authService = AuthService();
