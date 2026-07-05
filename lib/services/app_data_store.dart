import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/alert_model.dart';
import '../models/camera_model.dart';
import '../models/emergency_contact_model.dart';
import '../models/notification_model.dart';

/// Single in-memory source of truth for the app.
///
/// Simulates a live monitoring feed (new alerts/notifications arrive on a
/// timer) so the UI reflects a running surveillance system instead of a
/// frozen mock. Everything downstream (dashboard, alerts, notifications,
/// map, profile) reads from and mutates this one store.
class AppDataStore extends ChangeNotifier {
  AppDataStore() {
    _seed();
    _liveFeedTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _tick();
    });
  }

  final _rng = Random();
  late final Timer _liveFeedTimer;
  int _idCounter = 100;

  final List<CameraModel> cameras = [
    // Rawalpindi / Islamabad
    const CameraModel(id: 'CAM-01', label: 'Saddar Market, Rawalpindi', point: LatLng(33.7294, 73.0931)),
    const CameraModel(id: 'CAM-02', label: 'Raja Bazaar, Rawalpindi', point: LatLng(33.7296, 73.0880)),
    const CameraModel(id: 'CAM-03', label: 'Blue Area, Islamabad', point: LatLng(33.7215, 73.0433)),
    const CameraModel(id: 'CAM-04', label: 'F-10 Markaz, Islamabad', point: LatLng(33.7080, 73.0479)),
    const CameraModel(id: 'CAM-05', label: 'Centaurus Mall, Islamabad', point: LatLng(33.6938, 73.0651)),
    const CameraModel(id: 'CAM-06', label: 'Liaquat Bagh, Rawalpindi', point: LatLng(33.6844, 73.0479)),
    const CameraModel(id: 'CAM-07', label: 'G-9 Markaz, Islamabad', point: LatLng(33.6996, 73.0362), online: false),
    // Lahore
    const CameraModel(id: 'CAM-08', label: 'Mall Road, Lahore', point: LatLng(31.5497, 74.3436)),
    const CameraModel(id: 'CAM-09', label: 'Liberty Market, Lahore', point: LatLng(31.5085, 74.3436)),
    // Karachi
    const CameraModel(id: 'CAM-10', label: 'Saddar Town, Karachi', point: LatLng(24.8608, 67.0104)),
    const CameraModel(id: 'CAM-11', label: 'Clifton Beach, Karachi', point: LatLng(24.8138, 67.0299)),
    // Other major cities
    const CameraModel(id: 'CAM-12', label: 'Qissa Khwani Bazaar, Peshawar', point: LatLng(34.0083, 71.5787)),
    const CameraModel(id: 'CAM-13', label: 'Liaquat Bazaar, Quetta', point: LatLng(30.1798, 66.9750)),
    const CameraModel(id: 'CAM-14', label: 'Ghanta Ghar, Multan', point: LatLng(30.1978, 71.4697)),
    const CameraModel(id: 'CAM-15', label: 'Clock Tower, Faisalabad', point: LatLng(31.4187, 73.0791), online: false),
    const CameraModel(id: 'CAM-16', label: 'Cantt Area, Sialkot', point: LatLng(32.4927, 74.5310)),
  ];

  final List<AlertModel> alerts = [];
  final List<NotificationModel> notifications = [];
  final List<EmergencyContact> contacts = [
    const EmergencyContact(
      id: 'c1',
      name: 'Fatima Khan',
      relation: 'Mother',
      phone: '+92 300 1234567',
      icon: Icons.favorite_outline,
      color: Color(0xFFEF4444),
    ),
    const EmergencyContact(
      id: 'c2',
      name: 'Ahmed Khan',
      relation: 'Brother',
      phone: '+92 301 7654321',
      icon: Icons.person_outline,
      color: Color(0xFF4A7FC4),
    ),
    const EmergencyContact(
      id: 'c3',
      name: 'Rescue 1122',
      relation: 'Emergency Service',
      phone: '1122',
      icon: Icons.local_police_outlined,
      color: Color(0xFFF59E0B),
    ),
  ];

  final Map<String, bool> preferences = {
    'Avoid Isolated Areas': true,
    'Prefer Crowded Routes': true,
    'Night Mode Alerts': false,
  };

  int get unreadCount => notifications.where((n) => !n.read).length;

  int get criticalCount => alerts.where((a) => a.severity == AlertSeverity.high).length;

  String get riskLevel {
    if (criticalCount > 0) return 'HIGH';
    final medium = alerts.where((a) => a.severity == AlertSeverity.medium).length;
    if (medium > 1) return 'MED';
    return 'LOW';
  }

  int get offlineCameraCount => cameras.where((c) => !c.online).length;

  int get todayAlertCount {
    final now = DateTime.now();
    return alerts
        .where((a) => a.time.year == now.year && a.time.month == now.month && a.time.day == now.day)
        .length;
  }

  /// A composite 0-100 city safety score derived from the current alert mix
  /// and camera coverage — not a fixed number, it moves as real alerts/
  /// cameras change.
  int get safetyScore {
    final medium = alerts.where((a) => a.severity == AlertSeverity.medium).length;
    final low = alerts.where((a) => a.severity == AlertSeverity.low).length;
    var score = 100 - (criticalCount * 12) - (medium * 5) - (low * 2);
    if (cameras.isNotEmpty) {
      final offlineRatio = offlineCameraCount / cameras.length;
      score -= (offlineRatio * 15).round();
    }
    return score.clamp(0, 100);
  }

  static const _eventPool = [
    _EventTemplate('Fight Detected', AlertSeverity.high, Icons.sports_kabaddi_outlined),
    _EventTemplate('Weapon Detected', AlertSeverity.high, Icons.warning_amber_rounded),
    _EventTemplate('Crowd Anomaly', AlertSeverity.medium, Icons.groups_outlined),
    _EventTemplate('Panic Movement', AlertSeverity.medium, Icons.directions_run),
    _EventTemplate('Suspicious Activity', AlertSeverity.low, Icons.visibility_outlined),
    _EventTemplate('Overcrowding', AlertSeverity.low, Icons.people_outlined),
  ];

  void _seed() {
    final now = DateTime.now();
    final seeds = [
      (0, 'Fight Detected', AlertSeverity.high, Icons.sports_kabaddi_outlined, 2),
      (2, 'Crowd Anomaly', AlertSeverity.medium, Icons.groups_outlined, 15),
      (1, 'Weapon Detected', AlertSeverity.high, Icons.warning_amber_rounded, 42),
      (3, 'Suspicious Activity', AlertSeverity.low, Icons.visibility_outlined, 60),
      (4, 'Panic Movement', AlertSeverity.medium, Icons.directions_run, 120),
      (5, 'Overcrowding', AlertSeverity.low, Icons.people_outlined, 180),
    ];
    for (final s in seeds) {
      final cam = cameras[s.$1];
      alerts.add(AlertModel(
        id: 'A${_idCounter++}',
        type: s.$2,
        location: cam.label,
        loc: cam.point,
        time: now.subtract(Duration(minutes: s.$5)),
        severity: s.$3,
        icon: s.$4,
      ));
    }

    notifications.addAll([
      NotificationModel(
        id: 'N${_idCounter++}',
        title: 'Fight Detected',
        body: 'High severity event flagged at Saddar Market.',
        time: now.subtract(const Duration(minutes: 2)),
        type: NotificationType.alert,
        icon: Icons.sports_kabaddi_outlined,
      ),
      NotificationModel(
        id: 'N${_idCounter++}',
        title: 'Weapon Detected',
        body: 'High severity event flagged at Raja Bazaar.',
        time: now.subtract(const Duration(minutes: 42)),
        type: NotificationType.alert,
        icon: Icons.warning_amber_rounded,
      ),
      NotificationModel(
        id: 'N${_idCounter++}',
        title: 'Safety Tip',
        body: 'Enable Night Mode Alerts for extra protection after 9 PM.',
        time: now.subtract(const Duration(hours: 5)),
        type: NotificationType.safety,
        icon: Icons.shield_outlined,
        read: true,
      ),
      NotificationModel(
        id: 'N${_idCounter++}',
        title: 'System Update',
        body: 'CAM-07 (G-9 Markaz) went offline for maintenance.',
        time: now.subtract(const Duration(hours: 9)),
        type: NotificationType.system,
        icon: Icons.videocam_off_outlined,
        read: true,
      ),
    ]);
  }

  void _tick() {
    // ~55% chance every tick that the monitoring pipeline reports a new event.
    if (_rng.nextDouble() > 0.55) return;

    final template = _eventPool[_rng.nextInt(_eventPool.length)];
    final onlineCams = cameras.where((c) => c.online).toList();
    final cam = onlineCams[_rng.nextInt(onlineCams.length)];
    final now = DateTime.now();

    final alert = AlertModel(
      id: 'A${_idCounter++}',
      type: template.type,
      location: cam.label,
      loc: cam.point,
      time: now,
      severity: template.severity,
      icon: template.icon,
    );
    alerts.insert(0, alert);
    if (alerts.length > 40) alerts.removeLast();

    notifications.insert(
      0,
      NotificationModel(
        id: 'N${_idCounter++}',
        title: template.type,
        body: '${_severityLabel(template.severity)} severity event flagged at ${cam.label}.',
        time: now,
        type: NotificationType.alert,
        icon: template.icon,
      ),
    );
    if (notifications.length > 40) notifications.removeLast();

    notifyListeners();
  }

  String _severityLabel(AlertSeverity s) => switch (s) {
        AlertSeverity.high => 'High',
        AlertSeverity.medium => 'Medium',
        AlertSeverity.low => 'Low',
      };

  void markNotificationRead(String id) {
    final n = notifications.firstWhere((n) => n.id == id);
    if (!n.read) {
      n.read = true;
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void dismissNotification(String id) {
    notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void acknowledgeAlert(String id) {
    final a = alerts.firstWhere((a) => a.id == id);
    a.acknowledged = true;
    notifyListeners();
  }

  void addContact(EmergencyContact contact) {
    contacts.add(contact);
    notifyListeners();
  }

  void removeContact(String id) {
    contacts.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void setPreference(String key, bool value) {
    preferences[key] = value;
    notifyListeners();
  }

  void triggerSOS() {
    final now = DateTime.now();
    notifications.insert(
      0,
      NotificationModel(
        id: 'N${_idCounter++}',
        title: 'SOS Activated',
        body: 'Your live location was shared with all emergency contacts.',
        time: now,
        type: NotificationType.safety,
        icon: Icons.sos_rounded,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _liveFeedTimer.cancel();
    super.dispose();
  }
}

class _EventTemplate {
  final String type;
  final AlertSeverity severity;
  final IconData icon;
  const _EventTemplate(this.type, this.severity, this.icon);
}
