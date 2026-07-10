import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../constants/app_colors.dart';

Color severityColor(AlertSeverity s) => switch (s) {
      AlertSeverity.critical => AppColors.danger,
      AlertSeverity.high => AppColors.danger,
      AlertSeverity.medium => AppColors.accentOrange,
      AlertSeverity.low => AppColors.accent,
    };
