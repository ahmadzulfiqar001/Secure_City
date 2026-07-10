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

  /// Backend only stores name/relation/phone — it has no notion of Flutter
  /// icons/colors, so we derive a sensible one from the relation text.
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final relation = json['relation'] as String;
    final r = relation.toLowerCase();
    IconData icon;
    Color color;
    if (r.contains('mother') || r.contains('father') || r.contains('parent') || r.contains('family')) {
      icon = Icons.favorite_outline;
      color = const Color(0xFFEF4444);
    } else if (r.contains('emergency') || r.contains('rescue') || r.contains('police') || r.contains('service')) {
      icon = Icons.local_police_outlined;
      color = const Color(0xFFF59E0B);
    } else {
      icon = Icons.person_outline;
      color = const Color(0xFF4A7FC4);
    }
    return EmergencyContact(
      id: '${json['id']}',
      name: json['name'] as String,
      relation: relation,
      phone: json['phone'] as String,
      icon: icon,
      color: color,
    );
  }
}
