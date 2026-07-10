import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/secure_storage_service.dart';

enum AuthStatus { initial, authenticating, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;

  const AuthState({required this.status, this.user});

  const AuthState.initial() : this(status: AuthStatus.initial);

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, UserModel? user}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user);
}

/// Returned by [AuthNotifier.register] — registration no longer logs the
/// user in directly, it just creates the (unverified) account and leaves it
/// to the caller to show the OTP screen.
class RegisterResult {
  final String email;
  final String? otpDebug;
  RegisterResult(this.email, this.otpDebug);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.initial()) {
    ApiClient.instance.tokenProvider = () => _accessToken;
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
  }

  String? _accessToken;
  bool _handlingUnauthorized = false;

  /// Whether the session should survive an app restart. Defaults to true;
  /// the login screen's "Remember Me" checkbox flips this before calling
  /// [login]. When false, tokens are cleared right after a successful
  /// login/verify instead of persisted.
  bool rememberMe = true;

  /// Restores a previously persisted session, if any. Call once at app
  /// boot (from the splash screen) before the router makes its first
  /// redirect decision.
  Future<void> bootstrap() async {
    final refreshToken = await SecureStorageService.getRefreshToken();
    if (refreshToken == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final res = await ApiClient.instance.dio.post('/api/v1/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      await _persistSession(res.data);
    } catch (_) {
      await SecureStorageService.clear();
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    }
  }

  Future<RegisterResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/v1/auth/register', data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      });
      return RegisterResult(email, res.data['otp_debug'] as String?);
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> verifyOtp({required String email, required String code}) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/v1/auth/verify-otp', data: {
        'email': email,
        'code': code,
      });
      await _persistSession(res.data);
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<String?> resendOtp({required String email}) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/v1/auth/resend-otp', data: {'email': email});
      return res.data['otp_debug'] as String?;
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _persistSession(res.data);
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<String?> forgotPassword({required String email}) async {
    try {
      final res = await ApiClient.instance.dio.post('/api/v1/auth/forgot-password', data: {'email': email});
      return res.data['otp_debug'] as String?;
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
      await ApiClient.instance.dio.post('/api/v1/auth/reset-password', data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      });
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    try {
      final res = await ApiClient.instance.dio.put('/api/v1/auth/me', data: {'name': name, 'phone': phone});
      final updated = UserModel.fromJson(Map<String, dynamic>.from(res.data as Map));
      state = state.copyWith(user: updated);
      if (rememberMe) {
        final refreshToken = await SecureStorageService.getRefreshToken();
        if (_accessToken != null && refreshToken != null) {
          await SecureStorageService.saveSession(
            accessToken: _accessToken!,
            refreshToken: refreshToken,
            user: updated.toJson(),
          );
        }
      }
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  /// The backend revokes every refresh token for the user on a successful
  /// password change (backend/app/services/auth_service.py:108-113), so the
  /// current session is dead the moment this succeeds — log out locally too
  /// rather than pretending the session survives.
  Future<void> changePassword({required String current, required String newPassword}) async {
    try {
      await ApiClient.instance.dio.post('/api/v1/auth/change-password', data: {
        'current_password': current,
        'new_password': newPassword,
      });
      await logout();
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await ApiClient.instance.dio.delete('/api/v1/auth/me');
      await logout();
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> logout() async {
    final refreshToken = await SecureStorageService.getRefreshToken();
    if (refreshToken != null) {
      try {
        await ApiClient.instance.dio.post('/api/v1/auth/logout', data: {'refresh_token': refreshToken});
      } catch (_) {
        // Best-effort server-side revocation — clear the local session
        // regardless of whether this reaches the backend.
      }
    }
    await SecureStorageService.clear();
    _accessToken = null;
    state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
  }

  Future<void> _persistSession(dynamic data) async {
    _accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final user = UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    if (rememberMe) {
      await SecureStorageService.saveSession(
        accessToken: _accessToken!,
        refreshToken: refreshToken,
        user: user.toJson(),
      );
    } else {
      await SecureStorageService.clear();
    }
    state = state.copyWith(status: AuthStatus.authenticated, user: user);
  }

  /// Called by [ApiClient] when a request that carried a token comes back
  /// 401 and a silent refresh also failed — the session itself is
  /// invalid/expired. Flips state to unauthenticated; the router redirect
  /// handles bouncing to the login screen.
  void _handleUnauthorized() {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    logout().whenComplete(() => _handlingUnauthorized = false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

/// Persists whether onboarding has been shown, independent of auth state —
/// a logged-out returning user shouldn't see onboarding again.
class OnboardingFlag {
  static const _key = 'securecity_onboarding_seen';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
