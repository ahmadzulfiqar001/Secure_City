import 'package:flutter/material.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String relation;
  final String phone;
  final IconData icon;
  final Color color;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    required this.icon,
    required this.color,
  });
}
