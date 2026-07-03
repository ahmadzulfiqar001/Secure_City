import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum AlertSeverity { high, medium, low }

class AlertModel {
  final String id;
  final String type;
  final String location;
  final LatLng loc;
  final DateTime time;
  final AlertSeverity severity;
  final IconData icon;
  bool acknowledged;

  AlertModel({
    required this.id,
    required this.type,
    required this.location,
    required this.loc,
    required this.time,
    required this.severity,
    required this.icon,
    this.acknowledged = false,
  });
}
