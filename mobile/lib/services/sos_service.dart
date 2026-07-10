import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

class SosLocationResult {
  final double? lat;
  final double? lng;
  final String? error;
  const SosLocationResult({this.lat, this.lng, this.error});
  bool get hasLocation => lat != null && lng != null;
}

/// Real device GPS + real backend reporting + a real native SMS composer —
/// no paid SMS gateway is configured, so "message my contacts" opens the
/// phone's own SMS app pre-filled with a Google Maps link, the same
/// mechanism most consumer safety apps use without their own telco account.
class SosService {
  static Future<SosLocationResult> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const SosLocationResult(error: 'Location services are turned off.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return const SosLocationResult(error: 'Location permission denied.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      return SosLocationResult(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return const SosLocationResult(error: 'Could not get your location.');
    }
  }

  /// Logs the SOS as a real high-severity alert on the backend (visible in
  /// the admin dashboard's live feed). Returns false on any failure —
  /// network/auth issues should never block the rest of the SOS flow.
  static Future<bool> reportToBackend(double lat, double lng) async {
    try {
      await ApiClient.instance.dio.post('/api/v1/sos', data: {'lat': lat, 'lng': lng});
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sendEmergencySms(List<String> phones, String message) async {
    if (phones.isEmpty) return false;
    final uri = Uri(scheme: 'sms', path: phones.join(','), queryParameters: {'body': message});
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
