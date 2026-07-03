import 'package:flutter/material.dart';

enum NotificationType { alert, system, safety }

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final NotificationType type;
  final IconData icon;
  bool read;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    required this.icon,
    this.read = false,
  });
}
