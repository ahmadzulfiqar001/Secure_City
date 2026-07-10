import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';

/// The primary call-to-action button — a gold gradient with a built-in
/// loading spinner state, replacing the repeated
/// `ElevatedButton.styleFrom(backgroundColor: AppColors.primary)` pattern
/// that used to be copy-pasted into every auth screen.
class PrimaryGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          gradient: LinearGradient(
            colors: disabled
                ? [AppColors.primary.withValues(alpha: 0.4), AppColors.primaryDark.withValues(alpha: 0.4)]
                : [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
