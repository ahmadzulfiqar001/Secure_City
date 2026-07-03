import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/notification_model.dart';
import '../../services/app_data_store.dart';

class NotificationsScreen extends StatelessWidget {
  final AppDataStore store;
  const NotificationsScreen({super.key, required this.store});

  Color _typeColor(NotificationType t) => switch (t) {
        NotificationType.alert => AppColors.danger,
        NotificationType.system => AppColors.accent,
        NotificationType.safety => AppColors.primary,
      };

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
            style: GoogleFonts.orbitron(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (_, __) => TextButton(
              onPressed: store.unreadCount == 0
                  ? null
                  : () => store.markAllNotificationsRead(),
              child: Text('Mark all read',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: store.unreadCount == 0
                          ? AppColors.textMuted
                          : AppColors.primaryLight)),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (_, __) {
          final items = store.notifications;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      color: AppColors.textMuted, size: 40),
                  const SizedBox(height: 12),
                  Text('No notifications',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
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
                onDismissed: (_) => store.dismissNotification(n.id),
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
                    border: Border.all(
                        color: n.read
                            ? AppColors.border
                            : color.withValues(alpha: 0.35)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => store.markNotificationRead(n.id),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle),
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
                                              fontWeight: n.read
                                                  ? FontWeight.w500
                                                  : FontWeight.w700)),
                                    ),
                                    if (!n.read)
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                            color: AppColors.primary, shape: BoxShape.circle),
                                      ),
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(n.body,
                                      style: GoogleFonts.inter(
                                          color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
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
    );
  }
}
