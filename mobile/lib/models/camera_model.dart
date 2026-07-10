import 'package:latlong2/latlong.dart';

class CameraModel {
  final String id;
  final String code;
  final String label;
  final LatLng point;
  final String status;

  const CameraModel({
    required this.id,
    required this.code,
    required this.label,
    required this.point,
    this.status = 'online',
  });

  bool get online => status == 'online';

  /// Builds a [CameraModel] from the backend's `CameraOut` schema
  /// (backend/app/schemas/camera.py).
  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id: '${json['id']}',
      code: json['code'] as String,
      label: json['name'] as String,
      point: LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
      status: json['status'] as String? ?? 'offline',
    );
  }
}
