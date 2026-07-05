import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class GeocodeResult {
  final String label;
  final LatLng point;
  const GeocodeResult(this.label, this.point);
}

/// Free place search via OpenStreetMap's Nominatim API — no API key needed.
/// Deliberately a bare Dio instance (not [ApiClient.instance.dio]): that one
/// attaches our own backend's JWT to every request, which must never be sent
/// to a third-party service.
class GeocodingService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'User-Agent': 'SecureCityApp/1.0 (FYP prototype; no contact configured)'},
  ));

  static Future<List<GeocodeResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _dio.get('/search', queryParameters: {
        'format': 'json',
        'q': query,
        'countrycodes': 'pk',
        'limit': 6,
      });
      final data = res.data as List;
      return data
          .map((r) => GeocodeResult(
                r['display_name'] as String,
                LatLng(double.parse(r['lat'] as String), double.parse(r['lon'] as String)),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
