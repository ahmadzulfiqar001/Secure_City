import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'sos_service.dart';

class WeatherInfo {
  final double tempC;
  final String label;
  final IconData icon;
  const WeatherInfo({required this.tempC, required this.label, required this.icon});
}

/// WMO weather codes (https://open-meteo.com/en/docs) collapsed into a
/// short label + icon — Open-Meteo returns a numeric code, not text.
(String, IconData) _describe(int code) {
  if (code == 0) return ('Clear sky', Icons.wb_sunny_outlined);
  if (code <= 3) return ('Partly cloudy', Icons.wb_cloudy_outlined);
  if (code == 45 || code == 48) return ('Fog', Icons.foggy);
  if (code >= 51 && code <= 67) return ('Rain', Icons.water_drop_outlined);
  if (code >= 71 && code <= 86) return ('Snow', Icons.ac_unit);
  if (code >= 95) return ('Thunderstorm', Icons.thunderstorm_outlined);
  return ('Overcast', Icons.cloud_outlined);
}

/// Open-Meteo is a free, keyless public API unrelated to the SecureCity
/// backend, so this uses its own bare [Dio] rather than [ApiClient]
/// (which points at the backend and attaches an auth header neither
/// wanted nor needed here).
class WeatherService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.open-meteo.com',
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  /// Returns null on any failure (location denied, offline, ...) — the
  /// weather chip simply doesn't render rather than showing fake data.
  static Future<WeatherInfo?> fetchForCurrentLocation() async {
    final location = await SosService.getCurrentLocation();
    if (!location.hasLocation) return null;

    try {
      final res = await _dio.get('/v1/forecast', queryParameters: {
        'latitude': location.lat,
        'longitude': location.lng,
        'current': 'temperature_2m,weather_code',
      });
      final current = res.data['current'] as Map;
      final temp = (current['temperature_2m'] as num).toDouble();
      final code = (current['weather_code'] as num).toInt();
      final (label, icon) = _describe(code);
      return WeatherInfo(tempC: temp, label: label, icon: icon);
    } catch (_) {
      return null;
    }
  }
}
