import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/severity_utils.dart';
import '../core/utils/time_utils.dart';
import '../models/alert_model.dart';

class AlertTile extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onTap;

  const AlertTile({super.key, required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(alert.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(alert.icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(alert.type,
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    if (alert.resolved)
                      const Icon(Icons.task_alt, color: AppColors.accent, size: 14)
                    else if (alert.acknowledged)
                      const Icon(Icons.check_circle_outline, color: AppColors.textMuted, size: 14),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 12),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(alert.location,
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              )),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(timeAgo(alert.time),
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    alert.severity.name.toUpperCase(),
                    style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
