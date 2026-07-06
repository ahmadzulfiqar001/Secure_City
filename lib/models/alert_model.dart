import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum AlertSeverity { high, medium, low }

AlertSeverity _severityFromString(String s) => switch (s.toLowerCase()) {
      'high' => AlertSeverity.high,
      'medium' => AlertSeverity.medium,
      _ => AlertSeverity.low,
    };

/// Picks an icon from the alert's `type` string — the backend only sends
/// text, not an icon, since it has no notion of Flutter widgets.
IconData iconForAlertType(String type) {
  final t = type.toLowerCase();
  if (t.contains('sos')) return Icons.sos_rounded;
  if (t.contains('fight')) return Icons.sports_kabaddi_outlined;
  if (t.contains('weapon') || t.contains('gun') || t.contains('knife')) return Icons.warning_amber_rounded;
  if (t.contains('crowd') || t.contains('overcrowd')) return Icons.groups_outlined;
  if (t.contains('panic') || t.contains('running')) return Icons.directions_run;
  if (t.contains('fire') || t.contains('smoke')) return Icons.local_fire_department_outlined;
  if (t.contains('fall')) return Icons.elderly_outlined;
  return Icons.visibility_outlined;
}

class AlertModel {
  final String id;
  final String type;
  final String location;
  final LatLng loc;
  final DateTime time;
  final AlertSeverity severity;
  final IconData icon;
  bool acknowledged;
  bool resolved;

  AlertModel({
    required this.id,
    required this.type,
    required this.location,
    required this.loc,
    required this.time,
    required this.severity,
    required this.icon,
    this.acknowledged = false,
    this.resolved = false,
  });

  /// Builds an [AlertModel] from the JSON the FastAPI backend returns —
  /// see `backend/app/database.py`'s alert row shape.
  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: '${json['id']}',
      type: json['type'] as String,
      location: json['camera_name'] as String? ?? 'Unknown location',
      loc: LatLng((json['lat'] as num?)?.toDouble() ?? 0, (json['lng'] as num?)?.toDouble() ?? 0),
      time: DateTime.parse(json['ts'] as String).toLocal(),
      severity: _severityFromString(json['severity'] as String),
      icon: iconForAlertType(json['type'] as String),
      acknowledged: json['acknowledged'] as bool? ?? false,
      resolved: json['resolved'] as bool? ?? false,
    );
  }
}
