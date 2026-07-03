import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/severity_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/alert_model.dart';
import '../../services/app_data_store.dart';
import '../../widgets/alert_tile.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/logo_widget.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';

class DashboardScreen extends StatelessWidget {
  final AppDataStore store;
  final VoidCallback onSeeAllAlerts;

  const DashboardScreen({super.key, required this.store, required this.onSeeAllAlerts});

  void _showAlertInfo(BuildContext context, AlertModel alert) {
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
          if (!alert.acknowledged) store.acknowledgeAlert(alert.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  Color _riskColor(String level) => switch (level) {
        'HIGH' => AppColors.danger,
        'MED' => AppColors.accentOrange,
        _ => AppColors.accent,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final alerts = store.alerts;
        final recent = alerts.take(3).toList();
        final onlineCams = store.cameras.where((c) => c.online).length;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _statsRow(onlineCams),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Safety Map',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(height: 260, child: MapScreen(store: store)),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Alerts',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    GestureDetector(
                      onTap: onSeeAllAlerts,
                      child: Text('See All',
                          style: GoogleFonts.inter(color: AppColors.primaryLight, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            if (recent.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Center(
                    child: Text('No recent alerts — all clear',
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => AlertTile(alert: recent[i], onTap: () => _showAlertInfo(context, recent[i])),
                    childCount: recent.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          const SecureCityLogo(size: 40, animate: true),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SecureCity',
                  style: GoogleFonts.orbitron(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
              Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Monitoring Active', style: GoogleFonts.inter(fontSize: 11, color: AppColors.accent)),
              ]),
            ],
          ),
          const Spacer(),
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationsScreen(store: store)),
              ),
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
            ),
            if (store.unreadCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      store.unreadCount > 9 ? '9+' : '${store.unreadCount}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _statsRow(int onlineCams) {
    final riskLevel = store.riskLevel;
    return Row(children: [
      Expanded(child: _statCard('$onlineCams', 'Cameras', Icons.videocam_outlined, AppColors.accent)),
      const SizedBox(width: 10),
      Expanded(child: _statCard('${store.criticalCount}', 'Critical', Icons.warning_rounded, AppColors.danger)),
      const SizedBox(width: 10),
      Expanded(child: _statCard(riskLevel, 'Risk Level', Icons.shield_outlined, _riskColor(riskLevel))),
    ]);
  }

  Widget _statCard(String val, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(val, style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
      ]),
    );
  }
}
