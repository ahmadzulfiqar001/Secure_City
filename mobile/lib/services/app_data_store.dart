import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alert_model.dart';
import '../models/camera_model.dart';
import '../models/emergency_contact_model.dart';
import '../models/notification_model.dart';
import 'api_client.dart';
import 'local_notification_service.dart';
import 'realtime_service.dart';

/// Single in-memory source of truth for the app.
///
/// Alerts, cameras, and the city safety score are all real — fetched from
/// the backend on startup, then kept live over the `/ws` gateway
/// (`RealtimeService`) using the exact protocol documented in
/// `backend/docs/websocket_protocol.md`. If the backend is unreachable the
/// lists simply stay empty (and the realtime service keeps retrying with
/// backoff) rather than falling back to invented data.
class AppDataStore extends ChangeNotifier {
  AppDataStore() {
    _loadInitialAlerts();
    _loadCameras();
    _loadOverview();
    _realtime.connect();
    _realtimeSub = _realtime.events.listen(_onRealtimeEvent);
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
  final RealtimeService _realtime = RealtimeService();
  StreamSubscription<RealtimeEvent>? _realtimeSub;
  Timer? _overviewDebounce;
  bool _disposed = false;
  bool _backendReachable = false;
  int? _cityScore;

  bool get backendReachable => _backendReachable;

  final List<CameraModel> cameras = [];
  final List<AlertModel> alerts = [];
  final List<NotificationModel> notifications = [];

  /// Emergency contacts and safety preferences are persisted server-side,
  /// tied to the logged-in user (see /api/v1/contacts, /api/preferences).
  final List<EmergencyContact> contacts = [];
  final Map<String, bool> preferences = {
    'Avoid Isolated Areas': true,
    'Prefer Crowded Routes': true,
    'Night Mode Alerts': false,
  };

  int get unreadCount => notifications.where((n) => !n.read).length;

  int get criticalCount => alerts.where((a) => a.severity == AlertSeverity.critical).length;

  /// Derived from the same score thresholds the safety-score card uses, so
  /// the risk-level chip and the score card never disagree with each other.
  String get riskLevel {
    final score = safetyScore;
    if (score >= 80) return 'LOW';
    if (score >= 50) return 'MED';
    return 'HIGH';
  }

  int get offlineCameraCount => cameras.where((c) => !c.online).length;

  int get todayAlertCount {
    final now = DateTime.now();
    return alerts
        .where((a) => a.time.year == now.year && a.time.month == now.month && a.time.day == now.day)
        .length;
  }

  /// The backend-computed score (`AnalyticsService._city_safety_score`,
  /// derived from real open alerts + camera coverage) when reachable; falls
  /// back to a local heuristic so the card still shows something sane if
  /// the overview fetch failed.
  int get safetyScore {
    if (_cityScore != null) return _cityScore!;
    final medium = alerts.where((a) => a.severity == AlertSeverity.medium).length;
    final low = alerts.where((a) => a.severity == AlertSeverity.low).length;
    var score = 100 - (criticalCount * 15) - (alerts.where((a) => a.severity == AlertSeverity.high).length * 10) - (medium * 5) - (low * 2);
    if (cameras.isNotEmpty) {
      final offlineRatio = offlineCameraCount / cameras.length;
      score -= (offlineRatio * 15).round();
    }
    return score.clamp(0, 100);
  }

  // ── real alerts/cameras/overview: fetch + live WebSocket feed ───────
  Future<void> _loadInitialAlerts() async {
    try {
      final res = await ApiClient.instance.dio.get('/api/v1/alerts', queryParameters: {'page_size': 100});
      final list =
          (res.data['data'] as List).map((j) => AlertModel.fromJson(j as Map<String, dynamic>)).toList();
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

  Future<void> _loadCameras() async {
    try {
      final res = await ApiClient.instance.dio.get('/api/v1/cameras');
      final list =
          (res.data['data'] as List).map((j) => CameraModel.fromJson(j as Map<String, dynamic>)).toList();
      cameras
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {
      // stays empty; refreshCameras() offers a manual retry
    }
  }

  Future<void> _loadOverview() async {
    try {
      final res = await ApiClient.instance.dio.get('/api/v1/analytics/overview');
      final data = res.data['data'] as Map;
      _cityScore = data['city_safety_score'] as int;
      notifyListeners();
    } catch (_) {
      // keep the local heuristic fallback
    }
  }

  /// Debounced so a burst of events (e.g. several alerts in quick
  /// succession) doesn't fire a fresh overview fetch per event — still
  /// comfortably inside the "~1s" live-update requirement.
  void _scheduleOverviewRefresh() {
    _overviewDebounce?.cancel();
    _overviewDebounce = Timer(const Duration(milliseconds: 300), _loadOverview);
  }

  Future<void> refreshAlerts() => _loadInitialAlerts();
  Future<void> refreshCameras() => _loadCameras();
  Future<void> refreshOverview() => _loadOverview();

  void _onRealtimeEvent(RealtimeEvent event) {
    if (_disposed) return;
    _backendReachable = true;
    switch (event.event) {
      case 'alert.new':
        _onAlertNew(event.data);
      case 'alert.updated':
        _onAlertUpdated(event.data);
      case 'camera.status':
        _onCameraStatus(event.data);
      case 'notification.new':
        _onNotificationNew(event.data);
      default:
        // dashboard.tick / sos.triggered are staff-only and never reach a
        // citizen connection; ignore anything else defensively.
        return;
    }
  }

  void _onAlertNew(Map<String, dynamic> data) {
    try {
      final alert = AlertModel.fromJson(data);
      if (alerts.any((a) => a.id == alert.id)) return; // already have it
      alerts.insert(0, alert);
      if (alerts.length > 200) alerts.removeLast();

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

      notifyListeners();
      _scheduleOverviewRefresh();
    } catch (_) {
      // malformed message from the server; ignore rather than crash the feed
    }
  }

  void _onAlertUpdated(Map<String, dynamic> data) {
    try {
      final updated = AlertModel.fromJson(data);
      final index = alerts.indexWhere((a) => a.id == updated.id);
      if (index == -1) {
        alerts.insert(0, updated);
      } else {
        alerts[index] = updated;
      }
      notifyListeners();
      _scheduleOverviewRefresh();
    } catch (_) {
      // ignore malformed frame
    }
  }

  void _onCameraStatus(Map<String, dynamic> data) {
    try {
      final updated = CameraModel.fromJson(data);
      final index = cameras.indexWhere((c) => c.id == updated.id);
      if (index == -1) {
        cameras.add(updated);
      } else {
        cameras[index] = updated;
      }
      notifyListeners();
      _scheduleOverviewRefresh();
    } catch (_) {
      // ignore malformed frame
    }
  }

  void _onNotificationNew(Map<String, dynamic> data) {
    try {
      final type = switch (data['type'] as String?) {
        'safety' => NotificationType.safety,
        'alert' => NotificationType.alert,
        _ => NotificationType.system,
      };
      final icon = switch (type) {
        NotificationType.safety => Icons.shield_outlined,
        NotificationType.alert => Icons.warning_amber_rounded,
        NotificationType.system => Icons.notifications_outlined,
      };
      final title = data['title'] as String? ?? 'Notification';
      final body = data['body'] as String? ?? '';
      notifications.insert(
        0,
        NotificationModel(
          id: 'N${data['id'] ?? _idCounter++}',
          title: title,
          body: body,
          time: data['created_at'] != null ? DateTime.parse(data['created_at'] as String).toLocal() : DateTime.now(),
          type: type,
          icon: icon,
        ),
      );
      if (notifications.length > 60) notifications.removeLast();
      LocalNotificationService.instance.showAlert(title: title, body: body);
      notifyListeners();
    } catch (_) {
      // ignore malformed frame
    }
  }

  String _severityLabel(AlertSeverity s) => switch (s) {
        AlertSeverity.critical => 'Critical',
        AlertSeverity.high => 'High',
        AlertSeverity.medium => 'Medium',
        AlertSeverity.low => 'Low',
      };

  Future<void> acknowledgeAlert(String id) async {
    final a = alerts.firstWhere((a) => a.id == id);
    a.acknowledged = true;
    notifyListeners();
    try {
      await ApiClient.instance.dio.patch('/api/v1/alerts/$id/acknowledge');
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
      await ApiClient.instance.dio.patch('/api/v1/alerts/$id/resolve');
    } catch (_) {
      // best-effort
    }
  }

  Future<void> deleteAlert(String id) async {
    alerts.removeWhere((a) => a.id == id);
    notifyListeners();
    try {
      await ApiClient.instance.dio.delete('/api/v1/alerts/$id');
    } catch (_) {
      // best-effort; already removed locally
    }
  }

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
      final res = await ApiClient.instance.dio.get('/api/v1/contacts');
      contacts
        ..clear()
        ..addAll((res.data['data'] as List).map((j) => EmergencyContact.fromJson(j as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {
      // stay empty; profile screen offers a manual retry via refreshContacts()
    }
  }

  Future<void> refreshContacts() => _loadContacts();

  Future<void> addContact({required String name, required String relation, required String phone}) async {
    try {
      final res = await ApiClient.instance.dio
          .post('/api/v1/contacts', data: {'name': name, 'relation': relation, 'phone': phone});
      contacts.add(EmergencyContact.fromJson(res.data['data'] as Map<String, dynamic>));
      notifyListeners();
    } catch (e) {
      throw apiErrorMessage(e);
    }
  }

  Future<void> removeContact(String id) async {
    contacts.removeWhere((c) => c.id == id);
    notifyListeners();
    try {
      await ApiClient.instance.dio.delete('/api/v1/contacts/$id');
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
      // keep the local defaults set above — no v1 preferences endpoint exists yet
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
    _overviewDebounce?.cancel();
    _realtimeSub?.cancel();
    _realtime.dispose();
    super.dispose();
  }
}
