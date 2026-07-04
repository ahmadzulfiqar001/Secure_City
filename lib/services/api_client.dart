import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'token_store.dart';

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

/// Thin wrapper around a single Dio instance shared by the whole app, with
/// the stored JWT (if any) automatically attached to every request.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: backendBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStore.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;
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
