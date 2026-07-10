import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'primary_gradient_button.dart';

/// A full-section error with a retry action — distinct from an inline
/// SnackBar error, used when an entire screen/section failed to load.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl, horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.danger),
          const SizedBox(height: AppSpacing.lg),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 160,
              child: PrimaryGradientButton(label: 'Retry', onPressed: onRetry, height: 44),
            ),
          ],
        ],
      ),
    );
  }
}
