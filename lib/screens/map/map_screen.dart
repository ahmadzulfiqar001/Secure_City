import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/severity_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/alert_model.dart';
import '../../models/camera_model.dart';
import '../../services/app_data_store.dart';
import '../../widgets/info_sheet.dart';

class MapScreen extends StatefulWidget {
  final AppDataStore store;
  final bool fullScreen;
  final double? height;

  const MapScreen({super.key, required this.store, this.fullScreen = false, this.height});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapCtrl = MapController();

  static const _center = LatLng(33.7215, 73.0433);

  void _showCamInfo(CameraModel cam) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => InfoSheet(
        icon: Icons.videocam_rounded,
        iconColor: cam.online ? AppColors.primary : AppColors.textMuted,
        title: cam.id,
        subtitle: cam.label,
        status: cam.online ? 'Active — Live Feed' : 'Offline — Maintenance',
        statusColor: cam.online ? AppColors.accent : AppColors.textMuted,
      ),
    );
  }

  void _showAlertInfo(AlertModel alert) {
    final color = severityColor(alert.severity);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => InfoSheet(
        icon: alert.icon,
        iconColor: color,
        title: alert.type,
        subtitle: alert.location,
        status: timeAgo(alert.time),
        statusColor: color,
        badge: alert.severity.name.toUpperCase(),
      ),
    );
  }

  List<Marker> _buildMarkers(List<CameraModel> cameras, List<AlertModel> alerts) {
    final markers = <Marker>[];

    for (final cam in cameras) {
      final color = cam.online ? AppColors.primary : AppColors.textMuted;
      markers.add(Marker(
        point: cam.point,
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showCamInfo(cam),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)],
            ),
            child: Icon(cam.online ? Icons.videocam : Icons.videocam_off, color: Colors.white, size: 18),
          ),
        ),
      ));
    }

    for (final alert in alerts) {
      final color = severityColor(alert.severity);
      markers.add(Marker(
        point: alert.loc,
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _showAlertInfo(alert),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 2)],
            ),
            child: Icon(alert.icon, color: Colors.white, size: 16),
          ),
        ),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (_, __) {
        final recentAlerts = widget.store.alerts.take(12).toList();
        final mapWidget = ClipRRect(
          borderRadius: BorderRadius.circular(widget.fullScreen ? 0 : 16),
          child: SizedBox(
            height: widget.height ?? MediaQuery.of(context).size.height,
            child: Stack(children: [
              FlutterMap(
                mapController: _mapCtrl,
                options: const MapOptions(
                  initialCenter: _center,
                  initialZoom: 12.5,
                  interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.securecity.app',
                  ),
                  MarkerLayer(markers: _buildMarkers(widget.store.cameras, recentAlerts)),
                ],
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendRow(AppColors.primary, Icons.videocam, 'Camera'),
                      const SizedBox(height: 5),
                      _legendRow(AppColors.danger, Icons.warning_rounded, 'High'),
                      const SizedBox(height: 5),
                      _legendRow(AppColors.accentOrange, Icons.warning_amber_rounded, 'Medium'),
                      const SizedBox(height: 5),
                      _legendRow(AppColors.accent, Icons.info_outline, 'Low'),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => _mapCtrl.move(_center, 12.5),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                  ),
                ),
              ),
            ]),
          ),
        );

        if (!widget.fullScreen) return mapWidget;

        final cameraCount = widget.store.cameras.where((c) => c.online).length;
        return Stack(children: [
          mapWidget,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.background, AppColors.background.withValues(alpha: 0.9), Colors.transparent],
                ),
              ),
              child: Row(children: [
                _quickInfo(Icons.videocam, '$cameraCount', 'Cams', AppColors.primary),
                const SizedBox(width: 10),
                _quickInfo(Icons.warning_rounded,
                    '${recentAlerts.where((a) => a.severity == AlertSeverity.high).length}', 'Critical', AppColors.danger),
                const SizedBox(width: 10),
                _quickInfo(Icons.warning_amber_rounded,
                    '${recentAlerts.where((a) => a.severity == AlertSeverity.medium).length}', 'Medium', AppColors.accentOrange),
                const SizedBox(width: 10),
                _quickInfo(Icons.check_circle_outline,
                    '${recentAlerts.where((a) => a.severity == AlertSeverity.low).length}', 'Low', AppColors.accent),
              ]),
            ),
          ),
        ]);
      },
    );
  }

  Widget _legendRow(Color color, IconData icon, String label) {
    return Row(children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10)),
    ]);
  }

  Widget _quickInfo(IconData icon, String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(val, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 9)),
        ]),
      ),
    );
  }
}
