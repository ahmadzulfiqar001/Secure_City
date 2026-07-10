import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/severity_utils.dart';
import '../models/alert_model.dart';

/// A small colored pill for an [AlertSeverity] — the shared visual language
/// for severity across alert lists, map markers, and notifications.
class SeverityBadge extends StatelessWidget {
  final AlertSeverity severity;

  const SeverityBadge({super.key, required this.severity});

  String get _label => switch (severity) {
        AlertSeverity.critical => 'CRITICAL',
        AlertSeverity.high => 'HIGH',
        AlertSeverity.medium => 'MEDIUM',
        AlertSeverity.low => 'LOW',
      };

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}
