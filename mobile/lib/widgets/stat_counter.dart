import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';

/// A number + label pair for dashboards/stat rows — the JetBrains Mono
/// numeral is the Aegis Dark convention for anything data/count-like.
class StatCounter extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const StatCounter({super.key, required this.value, required this.label, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTheme.monoLarge(color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}
