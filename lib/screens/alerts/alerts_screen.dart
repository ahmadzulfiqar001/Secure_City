import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/severity_utils.dart';
import '../../core/utils/time_utils.dart';
import '../../models/alert_model.dart';
import '../../services/app_data_store.dart';
import '../../widgets/alert_tile.dart';
import '../../widgets/info_sheet.dart';

enum _SortMode { newest, oldest, severity }

class AlertsScreen extends StatefulWidget {
  final AppDataStore store;
  const AlertsScreen({super.key, required this.store});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertSeverity? _filter;
  _SortMode _sort = _SortMode.newest;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAlertInfo(AlertModel alert) {
    final color = severityColor(alert.severity);
    final (label, action) = alert.resolved
        ? ('Close', null)
        : alert.acknowledged
            ? ('Resolve', () => widget.store.resolveAlert(alert.id))
            : ('Acknowledge', () => widget.store.acknowledgeAlert(alert.id));

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
        badge: alert.resolved ? 'RESOLVED' : alert.severity.name.toUpperCase(),
        actionLabel: label,
        onAction: () {
          action?.call();
          Navigator.pop(context);
        },
      ),
    );
  }

  List<AlertModel> _visibleAlerts() {
    var list = widget.store.alerts.where((a) {
      if (_filter != null && a.severity != _filter) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return a.type.toLowerCase().contains(q) || a.location.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case _SortMode.newest:
        list.sort((a, b) => b.time.compareTo(a.time));
      case _SortMode.oldest:
        list.sort((a, b) => a.time.compareTo(b.time));
      case _SortMode.severity:
        const rank = {AlertSeverity.high: 0, AlertSeverity.medium: 1, AlertSeverity.low: 2};
        list.sort((a, b) => rank[a.severity]!.compareTo(rank[b.severity]!));
    }
    return list;
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
            final shown = _visibleAlerts();
            final criticalCount = all.where((a) => a.severity == AlertSeverity.high).length;

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Text('Alerts',
                      style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  if (!widget.store.backendReachable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('OFFLINE',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text('$criticalCount Critical',
                        style: GoogleFonts.inter(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search alerts...',
                          hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
                                  onPressed: () => setState(() {
                                    _searchCtrl.clear();
                                    _query = '';
                                  }),
                                ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_SortMode>(
                    initialValue: _sort,
                    onSelected: (v) => setState(() => _sort = v),
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      _sortItem(_SortMode.newest, 'Newest first'),
                      _sortItem(_SortMode.oldest, 'Oldest first'),
                      _sortItem(_SortMode.severity, 'Severity'),
                    ],
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.sort, color: AppColors.textMuted, size: 18),
                    ),
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
                        color: AppColors.danger, onTap: () => setState(() => _filter = AlertSeverity.high)),
                    const SizedBox(width: 8),
                    _filterChip('Medium', _filter == AlertSeverity.medium,
                        color: AppColors.accentOrange, onTap: () => setState(() => _filter = AlertSeverity.medium)),
                    const SizedBox(width: 8),
                    _filterChip('Low', _filter == AlertSeverity.low,
                        color: AppColors.accent, onTap: () => setState(() => _filter = AlertSeverity.low)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.card,
                  onRefresh: widget.store.refreshAlerts,
                  child: shown.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                          children: [
                            Center(
                              child: Text(
                                all.isEmpty
                                    ? (widget.store.backendReachable
                                        ? 'No alerts — all clear.'
                                        : 'Could not reach the monitoring server.\nPull down to retry.')
                                    : 'No alerts match your filters.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final alert = shown[i];
                            return Dismissible(
                              key: ValueKey(alert.id),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => widget.store.deleteAlert(alert.id),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.delete_outline, color: AppColors.danger),
                              ),
                              child: AlertTile(alert: alert, onTap: () => _showAlertInfo(alert)),
                            );
                          },
                        ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  PopupMenuItem<_SortMode> _sortItem(_SortMode mode, String label) {
    final active = _sort == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(children: [
        Icon(active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: active ? AppColors.primary : AppColors.textMuted, size: 16),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
      ]),
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
