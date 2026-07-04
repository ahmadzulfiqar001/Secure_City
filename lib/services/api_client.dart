import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

/// Thin wrapper around a single Dio instance shared by the whole app.
///
/// Doesn't know about AuthService directly (that would be circular — every
/// screen already depends on AuthService for the current user). Instead
/// AuthService plugs itself in via [tokenProvider] (read synchronously, once
/// per request) and [onUnauthorized] (called when a request that *did*
/// carry a token comes back 401 — i.e. the session itself is invalid/expired,
/// as opposed to a login/register attempt with the wrong credentials).
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
      onError: (error, handler) {
        final hadToken = error.requestOptions.headers.containsKey('Authorization');
        if (error.response?.statusCode == 401 && hadToken) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  String? Function()? tokenProvider;
  void Function()? onUnauthorized;
}

/// Turns a DioException into a short, user-presentable message.
String apiErrorMessage(Object error) {
  if (error is DioException) {
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
