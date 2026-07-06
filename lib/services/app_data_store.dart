import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/alert_model.dart';
import '../models/camera_model.dart';
import '../models/emergency_contact_model.dart';
import '../models/notification_model.dart';
import 'api_client.dart';
import 'local_notification_service.dart';

/// Single in-memory source of truth for the app.
///
/// Alerts are real: fetched from the backend's `/api/alerts` on startup and
/// then streamed live over `/ws/alerts` — the same pipeline the AI detection
/// engine and the admin dashboard use. If the backend is unreachable the
/// list simply stays empty (and a reconnect keeps retrying) rather than
/// falling back to invented data.
class AppDataStore extends ChangeNotifier {
  AppDataStore() {
    _loadInitialAlerts();
    _connectWebSocket();
    _loadContacts();
    _loadPreferences();
    notifications.add(NotificationModel(
      id: 'N0',
      title: 'Safety Tip',
      body: 'Enable Night Mode Alerts for extra protection after 9 PM.',
      time: DateTime.now(),
      type: NotificationType.safety,
      icon: Icons.shield_outlined,
      read: true,
    ));
  }

  int _idCounter = 1;
  WebSocketChannel? _channel;
  bool _disposed = false;
  bool _backendReachable = false;

  bool get backendReachable => _backendReachable;

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

  /// Emergency contacts and safety preferences are persisted server-side,
  /// tied to the logged-in user (see /api/contacts, /api/preferences) — they
  /// used to be local-only and vanished on logout/reinstall, which defeats
  /// the point given SOS depends on them.
  final List<EmergencyContact> contacts = [];
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

  // ── real alerts: fetch + live WebSocket feed ────────────────────────
  Future<void> _loadInitialAlerts() async {
    try {
      final res = await ApiClient.instance.dio.get('/api/alerts', queryParameters: {'limit': 60});
      final list = (res.data as List).map((j) => AlertModel.fromJson(j as Map<String, dynamic>)).toList();
      alerts
        ..clear()
        ..addAll(list);
      _backendReachable = true;
      notifyListeners();
    } catch (_) {
      _backendReachable = false;
      notifyListeners();
    }
  }

  void _connectWebSocket() {
    if (_disposed) return;
    try {
      final wsUrl = backendBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/alerts'));
      _channel!.stream.listen(
        _onAlertMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
      _backendReachable = true;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _backendReachable = false;
    notifyListeners();
    Timer(const Duration(seconds: 4), _connectWebSocket);
  }

  void _onAlertMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final alert = AlertModel.fromJson(json);
      if (alerts.any((a) => a.id == alert.id)) return; // already have it from the initial fetch
      alerts.insert(0, alert);
      if (alerts.length > 100) alerts.removeLast();

      final notifBody = '${_severityLabel(alert.severity)} severity event at ${alert.location}.';
      notifications.insert(
        0,
        NotificationModel(
          id: 'N${_idCounter++}',
          title: alert.type,
          body: notifBody,
          time: alert.time,
          type: NotificationType.alert,
          icon: alert.icon,
        ),
      );
      if (notifications.length > 60) notifications.removeLast();
      LocalNotificationService.instance.showAlert(title: alert.type, body: notifBody);

      _backendReachable = true;
      notifyListeners();
    } catch (_) {
      // malformed message from the server; ignore rather than crash the feed
    }
  }

  String _severityLabel(AlertSeverity s) => switch (s) {
        AlertSeverity.high => 'High',
        AlertSeverity.medium => 'Medium',
        AlertSeverity.low => 'Low',
      };

  Future<void> acknowledgeAlert(String id) async {
    final a = alerts.firstWhere((a) => a.id == id);
    a.acknowledged = true;
    notifyListeners();
    try {
      await ApiClient.instance.dio.patch('/api/alerts/$id/acknowledge');
    } catch (_) {
      // best-effort; local state already reflects the user's action
    }
  }

  Future<void> resolveAlert(String id) async {
    final a = alerts.firstWhere((a) => a.id == id);
    a.acknowledged = true;
    a.resolved = true;
    notifyListeners();
    try {
      await ApiClient.instance.dio.patch('/api/alerts/$id/resolve');
    } catch (_) {
      // best-effort
    }
  }

  Future<void> deleteAlert(String id) async {
    alerts.removeWhere((a) => a.id == id);
    notifyListeners();
    try {
      await ApiClient.instance.dio.delete('/api/alerts/$id');
    } catch (_) {
      // best-effort; already removed locally
    }
  }

  Future<void> refreshAlerts() => _loadInitialAlerts();

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

  Future<void> _loadContacts() async {
    try {
      final res = await ApiClient.instance.dio.get('/api/contacts');
      contacts
        ..clear()
        ..addAll((res.data as List).map((j) => EmergencyContact.fromJson(j as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {
      // stay empty; profile screen offers a manual retry via refreshContacts()
    }
  }

  Future<void> refreshContacts() => _loadContacts();

  Future<void> addContact({required String name, required String relation, required String phone}) async {
    try {
      final res = await ApiClient.instance.dio
          .post('/api/contacts', data: {'name': name, 'relation': relation, 'phone': phone});
      contacts.add(EmergencyContact.fromJson(res.data as Map<String, dynamic>));
      notifyListeners();
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> removeContact(String id) async {
    contacts.removeWhere((c) => c.id == id);
    notifyListeners();
    try {
      await ApiClient.instance.dio.delete('/api/contacts/$id');
    } catch (_) {
      // best-effort; already removed locally
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final res = await ApiClient.instance.dio.get('/api/preferences');
      final data = Map<String, dynamic>.from(res.data as Map);
      preferences.clear();
      data.forEach((k, v) => preferences[k] = v as bool);
      notifyListeners();
    } catch (_) {
      // keep the local defaults set above
    }
  }

  Future<void> setPreference(String key, bool value) async {
    preferences[key] = value;
    notifyListeners();
    try {
      await ApiClient.instance.dio.put('/api/preferences', data: {key: value});
    } catch (_) {
      // best-effort; local toggle already reflects the user's choice
    }
  }

  void triggerSOS({double? lat, double? lng, required bool reachedBackend, required bool smsOpened}) {
    final now = DateTime.now();
    final where = (lat != null && lng != null)
        ? 'at ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
        : '(location unavailable)';
    final body = [
      'Triggered $where.',
      reachedBackend ? 'Logged with the monitoring system.' : 'Could not reach the monitoring server.',
      smsOpened ? 'SMS app opened for your emergency contacts.' : 'Could not open the SMS app.',
    ].join(' ');
    notifications.insert(
      0,
      NotificationModel(
        id: 'N${_idCounter++}',
        title: 'SOS Activated',
        body: body,
        time: now,
        type: NotificationType.safety,
        icon: Icons.sos_rounded,
      ),
    );
    LocalNotificationService.instance.showAlert(title: 'SOS Activated', body: body);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    super.dispose();
  }
}
