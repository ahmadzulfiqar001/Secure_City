import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/alert_model.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/primary_gradient_button.dart';
import '../../widgets/pulse_dot.dart';
import '../../widgets/severity_badge.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/stat_counter.dart';

/// Dev-only route (`/dev/theme`, kDebugMode-gated) that renders every Aegis
/// Dark token and shared widget so the design system can be eyeballed in
/// one place instead of hunting through real screens.
class ThemeShowcaseScreen extends StatelessWidget {
  const ThemeShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Aegis Dark — Theme Showcase')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Colors', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _swatch('background', AppColors.background),
              _swatch('surface', AppColors.surface),
              _swatch('card', AppColors.card),
              _swatch('primary', AppColors.primary),
              _swatch('primaryLight', AppColors.primaryLight),
              _swatch('primaryDark', AppColors.primaryDark),
              _swatch('accent', AppColors.accent),
              _swatch('accentOrange', AppColors.accentOrange),
              _swatch('danger', AppColors.danger),
              _swatch('border', AppColors.border),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text('Type — Sora (display/headline/title)', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('Display Large', style: textTheme.displayLarge),
          Text('Headline Medium', style: textTheme.headlineMedium),
          Text('Title Medium', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xl),
          Text('Type — Inter (body/label)', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('Body Large — the quick brown fox', style: textTheme.bodyLarge),
          Text('Body Medium — the quick brown fox', style: textTheme.bodyMedium),
          Text('Label Large', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xl),
          Text('Type — JetBrains Mono (data/numeric)', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('042 391', style: AppTheme.monoLarge()),
          Text('12:04:37', style: AppTheme.monoMedium()),
          Text('CAM-06 · 14ms', style: AppTheme.monoSmall()),
          const SizedBox(height: AppSpacing.xxxl),
          Text('Widgets', style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                StatCounter(value: '47', label: 'Trips'),
                StatCounter(value: '45', label: 'Safe Arrivals'),
                StatCounter(value: '96%', label: 'Safety Score'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              SeverityBadge(severity: AlertSeverity.high),
              SizedBox(width: AppSpacing.sm),
              SeverityBadge(severity: AlertSeverity.medium),
              SizedBox(width: AppSpacing.sm),
              SeverityBadge(severity: AlertSeverity.low),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: const [
              PulseDot(),
              SizedBox(width: AppSpacing.sm),
              Text('Live monitoring feed', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(height: 48),
          const SizedBox(height: AppSpacing.lg),
          PrimaryGradientButton(label: 'Primary Action', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          const PrimaryGradientButton(label: 'Loading…', onPressed: null, loading: true),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(child: const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here yet', message: 'Empty state sample.')),
          const SizedBox(height: AppSpacing.lg),
          AppCard(child: ErrorState(message: 'Something went wrong.', onRetry: () {})),
        ],
      ),
    );
  }

  Widget _swatch(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}
