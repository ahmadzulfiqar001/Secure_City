import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/severity_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/alert_model.dart';
import '../../services/app_data_store.dart';
import '../../widgets/alert_tile.dart';
import '../../widgets/info_sheet.dart';

class AlertsScreen extends StatefulWidget {
  final AppDataStore store;
  const AlertsScreen({super.key, required this.store});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertSeverity? _filter;

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
        actionLabel: alert.acknowledged ? 'Close' : 'Acknowledge',
        onAction: () {
          if (!alert.acknowledged) widget.store.acknowledgeAlert(alert.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (_, __) {
            final all = widget.store.alerts;
            final shown = _filter == null
                ? all
                : all.where((a) => a.severity == _filter).toList();
            final criticalCount =
                all.where((a) => a.severity == AlertSeverity.high).length;

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Text('Alerts',
                      style: GoogleFonts.orbitron(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text('$criticalCount Critical',
                        style: GoogleFonts.inter(
                            color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip('All', _filter == null, onTap: () => setState(() => _filter = null)),
                    const SizedBox(width: 8),
                    _filterChip('High', _filter == AlertSeverity.high,
                        color: AppColors.danger,
                        onTap: () => setState(() => _filter = AlertSeverity.high)),
                    const SizedBox(width: 8),
                    _filterChip('Medium', _filter == AlertSeverity.medium,
                        color: AppColors.accentOrange,
                        onTap: () => setState(() => _filter = AlertSeverity.medium)),
                    const SizedBox(width: 8),
                    _filterChip('Low', _filter == AlertSeverity.low,
                        color: AppColors.accent,
                        onTap: () => setState(() => _filter = AlertSeverity.low)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text('No alerts in this category',
                            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: shown.length,
                        itemBuilder: (_, i) =>
                            AlertTile(alert: shown[i], onTap: () => _showAlertInfo(shown[i])),
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool active, {Color? color, required VoidCallback onTap}) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: active ? Colors.white : AppColors.textMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}
