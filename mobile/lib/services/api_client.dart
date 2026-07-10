import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'secure_storage_service.dart';

/// Backend base URL. Android emulators can't reach the host machine via
/// `localhost`, so we special-case that; every other target (web, Windows,
/// iOS simulator) reaches the FastAPI dev server directly.
String get backendBaseUrl {
  if (kIsWeb) return 'http://localhost:8000';
  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  } catch (_) {
    // Platform is unavailable in some embedder contexts; fall through.
  }
  return 'http://localhost:8000';
}

/// Requests to these paths never trigger the silent-refresh dance — a 401
/// here is a real credential/token failure, not a stale-access-token case.
bool _isAuthEntryPoint(String path) =>
    path.contains('/auth/login') || path.contains('/auth/register') || path.contains('/auth/refresh');

/// Thin wrapper around a single Dio instance shared by the whole app.
///
/// Doesn't know about the auth provider directly (that would be circular).
/// Instead the auth provider plugs itself in via [tokenProvider] (read
/// synchronously, once per request) and [onUnauthorized] (called only when
/// a request that carried a token comes back 401 *and* a silent refresh
/// attempt also failed — i.e. the session itself is dead).
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: backendBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final hadToken = error.requestOptions.headers.containsKey('Authorization');
        final path = error.requestOptions.path;
        if (error.response?.statusCode != 401 || !hadToken || _isAuthEntryPoint(path)) {
          handler.next(error);
          return;
        }

        final newAccessToken = await _refreshOnce();
        if (newAccessToken == null) {
          onUnauthorized?.call();
          handler.next(error);
          return;
        }

        // Retry the original request once with the fresh access token.
        try {
          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final response = await _dio.fetch(retryOptions);
          handler.resolve(response);
        } catch (retryError) {
          handler.next(error);
        }
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  String? Function()? tokenProvider;
  void Function()? onUnauthorized;

  // Refresh tokens are single-use and rotated server-side (see
  // backend/app/services/auth_service.py:73-85) — if two requests 401 at
  // once, only one of them may call /auth/refresh or the second call will
  // find the first's refresh token already revoked and force a spurious
  // logout. This shares one in-flight refresh across concurrent 401s.
  Future<String?>? _refreshInFlight;

  Future<String?> _refreshOnce() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  /// Public entry point for callers outside the dio interceptor (e.g. the
  /// realtime WS client refreshing before a reconnect) — shares the same
  /// in-flight guard so a concurrent HTTP 401 and a WS 4401 never both try
  /// to spend the same single-use refresh token.
  Future<String?> refreshAccessToken() => _refreshOnce();

  Future<String?> _doRefresh() async {
    final refreshToken = await SecureStorageService.getRefreshToken();
    if (refreshToken == null) return null;
    try {
      // A bare Dio instance — going through `_dio` would recurse through
      // this same interceptor.
      final response = await Dio(BaseOptions(baseUrl: backendBaseUrl)).post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newAccess = response.data['access_token'] as String;
      final newRefresh = response.data['refresh_token'] as String;
      await SecureStorageService.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
      return newAccess;
    } catch (_) {
      return null;
    }
  }
}

/// Turns a DioException into a short, user-presentable message.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 429) {
      return 'Too many attempts — please wait a moment and try again.';
    }
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Could not reach the server. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'Could not connect to the SecureCity server.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
