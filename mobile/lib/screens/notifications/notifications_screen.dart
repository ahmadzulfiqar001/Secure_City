import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/notification_model.dart';
import '../../services/app_data_store.dart';

class NotificationsScreen extends StatefulWidget {
  final AppDataStore store;
  const NotificationsScreen({super.key, required this.store});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  NotificationType? _category;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _typeColor(NotificationType t) => switch (t) {
        NotificationType.alert => AppColors.danger,
        NotificationType.system => AppColors.accent,
        NotificationType.safety => AppColors.primary,
      };

  String _typeLabel(NotificationType t) => switch (t) {
        NotificationType.alert => 'Alerts',
        NotificationType.system => 'System',
        NotificationType.safety => 'Safety',
      };

  List<NotificationModel> _visible(List<NotificationModel> all) {
    return all.where((n) {
      if (_category != null && n.type != _category) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications',
            style: GoogleFonts.orbitron(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          ListenableBuilder(
            listenable: widget.store,
            builder: (_, __) => TextButton(
              onPressed: widget.store.unreadCount == 0 ? null : () => widget.store.markAllNotificationsRead(),
              child: Text('Mark all read',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: widget.store.unreadCount == 0 ? AppColors.textMuted : AppColors.primaryLight)),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                hintText: 'Search notifications...',
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
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _categoryChip('All', null),
              const SizedBox(width: 8),
              _categoryChip(_typeLabel(NotificationType.alert), NotificationType.alert),
              const SizedBox(width: 8),
              _categoryChip(_typeLabel(NotificationType.safety), NotificationType.safety),
              const SizedBox(width: 8),
              _categoryChip(_typeLabel(NotificationType.system), NotificationType.system),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (_, __) {
              final items = _visible(widget.store.notifications);
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_off_outlined, color: AppColors.textMuted, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        widget.store.notifications.isEmpty ? 'No notifications' : 'No notifications match your filters',
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final n = items[i];
                  final color = _typeColor(n.type);
                  return Dismissible(
                    key: ValueKey(n.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => widget.store.dismissNotification(n.id),
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
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: n.read ? AppColors.card : AppColors.card.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: n.read ? AppColors.border : color.withValues(alpha: 0.35)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => widget.store.markNotificationRead(n.id),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                                  child: Icon(n.icon, color: color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                          child: Text(n.title,
                                              style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                                        ),
                                        if (!n.read)
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration:
                                                const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                          ),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(n.body,
                                          style:
                                              GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                                      const SizedBox(height: 6),
                                      Text(timeAgo(n.time),
                                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _categoryChip(String label, NotificationType? type) {
    final active = _category == type;
    final c = type == null ? AppColors.primary : _typeColor(type);
    return GestureDetector(
      onTap: () => setState(() => _category = type),
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
