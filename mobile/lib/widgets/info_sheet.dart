import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

class InfoSheet extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle, status;
  final Color statusColor;
  final String? badge;
  final VoidCallback? onAction;
  final String actionLabel;

  const InfoSheet({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.badge,
    this.onAction,
    this.actionLabel = 'Close',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        ),
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
            ],
          )),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: iconColor.withValues(alpha: 0.3)),
              ),
              child: Text(badge!,
                  style: GoogleFonts.inter(
                      color: iconColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.access_time, color: statusColor, size: 14),
          const SizedBox(width: 6),
          Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 13)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onAction ?? () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(actionLabel,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
