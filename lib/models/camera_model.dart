import 'package:latlong2/latlong.dart';

class CameraModel {
  final String id;
  final String label;
  final LatLng point;
  final bool online;

  const CameraModel({
    required this.id,
    required this.label,
    required this.point,
    this.online = true,
  });
}
