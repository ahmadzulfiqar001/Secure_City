import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/weather_service.dart';
import 'shimmer_box.dart';

/// Fetches once on mount; collapses to nothing on error or denied location
/// permission — no fake weather ever shown.
class WeatherChip extends StatefulWidget {
  const WeatherChip({super.key});

  @override
  State<WeatherChip> createState() => _WeatherChipState();
}

class _WeatherChipState extends State<WeatherChip> {
  late final Future<WeatherInfo?> _future = WeatherService.fetchForCurrentLocation();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherInfo?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ShimmerBox(width: 64, height: 26, borderRadius: AppRadius.pill);
        }
        final weather = snapshot.data;
        if (weather == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(weather.icon, size: 13, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                '${weather.tempC.round()}°C',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}
