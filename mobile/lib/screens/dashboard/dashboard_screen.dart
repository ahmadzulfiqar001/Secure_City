import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/greeting_utils.dart';
import '../../core/utils/severity_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/alert_model.dart';
import '../../models/emergency_contact_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_data_store.dart';
import '../../widgets/alert_tile.dart';
import '../../widgets/info_sheet.dart';
import '../../widgets/weather_chip.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';

class DashboardScreen extends ConsumerWidget {
  final AppDataStore store;
  final VoidCallback onSeeAllAlerts;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenProfile;

  const DashboardScreen({
    super.key,
    required this.store,
    required this.onSeeAllAlerts,
    required this.onOpenMap,
    required this.onOpenProfile,
  });

  void _showAlertInfo(BuildContext context, AlertModel alert) {
    final color = severityColor(alert.severity);
    final (label, action) = alert.resolved
        ? ('Close', null)
        : alert.acknowledged
            ? ('Resolve', () => store.resolveAlert(alert.id))
            : ('Acknowledge', () => store.acknowledgeAlert(alert.id));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Hero(
        tag: 'dashboard-alert-${alert.id}',
        child: Material(
          color: Colors.transparent,
          child: InfoSheet(
            icon: alert.icon,
            iconColor: color,
            title: alert.type,
            subtitle: alert.location,
            status: timeAgo(alert.time),
            statusColor: color,
            badge: alert.resolved ? 'RESOLVED' : alert.severity.name.toUpperCase(),
            actionLabel: label,
            onAction: () {
              action?.call();
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Color _riskColor(String level) => switch (level) {
        'HIGH' => AppColors.danger,
        'MED' => AppColors.accentOrange,
        _ => AppColors.accent,
      };

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.accent;
    if (score >= 50) return AppColors.accentOrange;
    return AppColors.danger;
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+'), ''));
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open the dialer on this device.', style: GoogleFonts.inter()),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final alerts = store.alerts;
        final recent = alerts.take(5).toList();
        final onlineCams = store.cameras.where((c) => c.online).length;
        final score = store.safetyScore;

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () => Future.wait([
            store.refreshAlerts(),
            store.refreshCameras(),
            store.refreshOverview(),
          ]),
          child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context, ref)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _safetyScoreCard(score),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _statsRow(onlineCams),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _quickActions(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _PulsingSosButton(onTap: () => context.push('/sos', extra: store)),
              ),
            ),
            if (store.contacts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _emergencyContactsStrip(context),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                    (_, i) => Hero(
                      tag: 'dashboard-alert-${recent[i].id}',
                      child: Material(
                        color: Colors.transparent,
                        child: AlertTile(alert: recent[i], onTap: () => _showAlertInfo(context, recent[i])),
                      ),
                    ),
                    childCount: recent.length,
                  ),
                ),
              ),
          ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider).user?.name ?? 'there';
    final firstName = name.split(RegExp(r'\s+')).first;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenProfile,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              ),
              child: Center(
                child: Text(initialsOf(name),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${timeOfDayGreeting()}, $firstName',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('Monitoring Active', style: GoogleFonts.inter(fontSize: 11, color: AppColors.accent)),
                const SizedBox(width: 8),
                const _LiveClock(),
              ]),
            ],
          ),
          const Spacer(),
          const WeatherChip(),
          const SizedBox(width: 8),
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

  Widget _safetyScoreCard(int score) {
    final color = _scoreColor(score);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        SizedBox(
          width: 66,
          height: 66,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, animatedScore, __) => Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 66,
                height: 66,
                child: CircularProgressIndicator(
                  value: animatedScore / 100,
                  strokeWidth: 6,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text('${animatedScore.round()}',
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('City Safety Score',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                score >= 80
                    ? 'Conditions look safe right now.'
                    : score >= 50
                        ? 'Some active alerts — stay aware.'
                        : 'Elevated risk — avoid affected areas.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _statsRow(int onlineCams) {
    final riskLevel = store.riskLevel;
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _statCard('$onlineCams', 'Cameras Online', Icons.videocam_outlined, AppColors.accent),
          const SizedBox(width: 10),
          _statCard('${store.offlineCameraCount}', 'Offline', Icons.videocam_off_outlined, AppColors.textMuted),
          const SizedBox(width: 10),
          _statCard('${store.todayAlertCount}', "Today's Alerts", Icons.today_outlined, AppColors.primary),
          const SizedBox(width: 10),
          _statCard('${store.criticalCount}', 'Critical', Icons.warning_rounded, AppColors.danger),
          const SizedBox(width: 10),
          _statCard(riskLevel, 'Risk Level', Icons.shield_outlined, _riskColor(riskLevel)),
        ],
      ),
    );
  }

  Widget _statCard(String val, String label, IconData icon, Color color) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(val, style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _quickActions(BuildContext context) {
    final emergencyContact = store.contacts.isNotEmpty
        ? store.contacts.firstWhere((c) => c.relation.toLowerCase().contains('emergency'),
            orElse: () => store.contacts.first)
        : null;

    return Row(children: [
      Expanded(
        child: _actionButton(
          Icons.call,
          'Emergency',
          AppColors.danger,
          emergencyContact == null ? null : () => _call(context, emergencyContact.phone),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: _actionButton(Icons.map_outlined, 'Live Map', AppColors.accent, onOpenMap)),
      const SizedBox(width: 10),
      Expanded(child: _actionButton(Icons.contacts_outlined, 'Contacts', AppColors.primary, onOpenProfile)),
      const SizedBox(width: 10),
      Expanded(child: _actionButton(Icons.notifications_active_outlined, 'Alerts', AppColors.accentOrange, onSeeAllAlerts)),
    ]);
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback? onTap) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            Icon(icon, color: onTap == null ? AppColors.textMuted : color, size: 20),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.inter(fontSize: 10, color: onTap == null ? AppColors.textMuted : Colors.white)),
          ]),
        ),
      ),
    );
  }

  Widget _emergencyContactsStrip(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Emergency Contacts',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: store.contacts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _contactCard(context, store.contacts[i]),
          ),
        ),
      ],
    );
  }

  Widget _contactCard(BuildContext context, EmergencyContact c) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _call(context, c.phone),
        child: Container(
          width: 130,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: c.color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(c.icon, color: c.color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.name,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(c.relation,
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.call, color: AppColors.accent, size: 14),
          ]),
        ),
      ),
    );
  }
}

/// A large, continuously pulsing SOS entry point — navigates to the
/// dedicated `/sos` route (shared with the home shell's own SOS FAB)
/// rather than opening a dialog.
class _PulsingSosButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PulsingSosButton({required this.onTap});

  @override
  State<_PulsingSosButton> createState() => _PulsingSosButtonState();
}

class _PulsingSosButtonState extends State<_PulsingSosButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  late final Animation<double> _glow = Tween<double>(begin: 0.25, end: 0.55).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
              boxShadow: [
                BoxShadow(color: AppColors.danger.withValues(alpha: _glow.value), blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sos_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Text('EMERGENCY SOS',
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ticks every second on its own — kept isolated so the rest of the
/// (otherwise stateless) dashboard doesn't rebuild once a second too.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _format(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Text('• ${_format(_now)}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted));
  }
}
