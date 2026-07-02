import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/constants/app_colors.dart';

class SecureCityLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const SecureCityLogo({super.key, this.size = 120, this.animate = true});

  @override
  State<SecureCityLogo> createState() => _SecureCityLogoState();
}

class _SecureCityLogoState extends State<SecureCityLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _LogoPainter(scanProgress: 0.5, glowOpacity: 0.5),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _LogoPainter(
          scanProgress: _controller.value,
          glowOpacity: (math.sin(_controller.value * 2 * math.pi) + 1) / 2,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double scanProgress;
  final double glowOpacity;

  _LogoPainter({required this.scanProgress, required this.glowOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer ambient glow
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      w * 0.52,
      Paint()
        ..color = AppColors.primary.withOpacity(0.12 + glowOpacity * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    final shieldPath = _shieldPath(size);

    // Shield fill
    canvas.drawPath(
      shieldPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1E0A48), const Color(0xFF0A0820)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // City skyline clipped inside shield
    canvas.save();
    canvas.clipPath(shieldPath);
    _drawSkyline(canvas, size);
    _drawScanLine(canvas, size);
    canvas.restore();

    // Shield border
    canvas.drawPath(
      shieldPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDark],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028,
    );

    // Center AI eye
    _drawEye(canvas, size);
  }

  Path _shieldPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..cubicTo(w * 0.76, h * 0.04, w * 0.95, h * 0.16, w * 0.95, h * 0.38)
      ..cubicTo(w * 0.95, h * 0.65, w * 0.75, h * 0.85, w * 0.5, h * 0.96)
      ..cubicTo(w * 0.25, h * 0.85, w * 0.05, h * 0.65, w * 0.05, h * 0.38)
      ..cubicTo(w * 0.05, h * 0.16, w * 0.24, h * 0.04, w * 0.5, h * 0.04)
      ..close();
  }

  void _drawSkyline(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final skylinePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.22)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(w * 0.05, h * 0.90)
      ..lineTo(w * 0.05, h * 0.73)
      ..lineTo(w * 0.10, h * 0.73)
      ..lineTo(w * 0.10, h * 0.66)
      ..lineTo(w * 0.15, h * 0.66)
      ..lineTo(w * 0.15, h * 0.73)
      ..lineTo(w * 0.20, h * 0.73)
      ..lineTo(w * 0.20, h * 0.58)
      ..lineTo(w * 0.215, h * 0.52)
      ..lineTo(w * 0.23, h * 0.58)
      ..lineTo(w * 0.27, h * 0.58)
      ..lineTo(w * 0.27, h * 0.68)
      ..lineTo(w * 0.33, h * 0.68)
      ..lineTo(w * 0.33, h * 0.56)
      ..lineTo(w * 0.37, h * 0.56)
      ..lineTo(w * 0.37, h * 0.68)
      ..lineTo(w * 0.42, h * 0.68)
      ..lineTo(w * 0.42, h * 0.73)
      ..lineTo(w * 0.58, h * 0.73)
      ..lineTo(w * 0.58, h * 0.68)
      ..lineTo(w * 0.63, h * 0.68)
      ..lineTo(w * 0.63, h * 0.56)
      ..lineTo(w * 0.67, h * 0.56)
      ..lineTo(w * 0.67, h * 0.68)
      ..lineTo(w * 0.73, h * 0.68)
      ..lineTo(w * 0.73, h * 0.58)
      ..lineTo(w * 0.77, h * 0.52)
      ..lineTo(w * 0.785, h * 0.58)
      ..lineTo(w * 0.80, h * 0.58)
      ..lineTo(w * 0.80, h * 0.73)
      ..lineTo(w * 0.85, h * 0.73)
      ..lineTo(w * 0.85, h * 0.66)
      ..lineTo(w * 0.90, h * 0.66)
      ..lineTo(w * 0.90, h * 0.73)
      ..lineTo(w * 0.95, h * 0.73)
      ..lineTo(w * 0.95, h * 0.90)
      ..close();

    canvas.drawPath(path, skylinePaint);

    // Building windows
    final winPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (final pt in [
      [0.07, 0.75], [0.09, 0.75], [0.07, 0.78], [0.09, 0.78],
      [0.21, 0.61], [0.23, 0.61], [0.21, 0.64],
      [0.34, 0.58], [0.36, 0.58], [0.34, 0.62],
      [0.64, 0.58], [0.66, 0.58], [0.64, 0.62],
      [0.74, 0.61], [0.74, 0.64], [0.76, 0.61],
      [0.86, 0.68], [0.88, 0.68],
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * pt[0], h * pt[1]),
            width: w * 0.02,
            height: h * 0.02,
          ),
          const Radius.circular(1),
        ),
        winPaint,
      );
    }
  }

  void _drawScanLine(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final scanY = h * 0.10 + (h * 0.80) * scanProgress;

    canvas.drawRect(
      Rect.fromLTWH(0, scanY - h * 0.03, w, h * 0.06),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.accent.withOpacity(0.55),
            AppColors.accent.withOpacity(0.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(0, scanY - h * 0.03, w, h * 0.06)),
    );
  }

  void _drawEye(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.5, h * 0.40);
    final r = w * 0.115;

    // Glow
    canvas.drawCircle(
      c, r * 1.2,
      Paint()
        ..color = AppColors.accent.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Outer ring
    canvas.drawCircle(
      c, r,
      Paint()
        ..color = AppColors.accent.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Iris gradient
    canvas.drawCircle(
      c, r * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [AppColors.accent, AppColors.primary],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.7)),
    );

    // Pupil
    canvas.drawCircle(c, r * 0.34, Paint()..color = const Color(0xFF0D0D2B));

    // Highlight
    canvas.drawCircle(
      Offset(c.dx - r * 0.13, c.dy - r * 0.13),
      r * 0.13,
      Paint()..color = Colors.white.withOpacity(0.85),
    );

    // Crosshair ticks
    final tickPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.45)
      ..strokeWidth = 0.9;
    final outer = r * 1.12;
    final inner = r * 1.25;

    canvas.drawLine(Offset(c.dx, c.dy - outer), Offset(c.dx, c.dy - inner), tickPaint);
    canvas.drawLine(Offset(c.dx, c.dy + outer), Offset(c.dx, c.dy + inner), tickPaint);
    canvas.drawLine(Offset(c.dx - outer, c.dy), Offset(c.dx - inner, c.dy), tickPaint);
    canvas.drawLine(Offset(c.dx + outer, c.dy), Offset(c.dx + inner, c.dy), tickPaint);

    // Corner brackets
    final bLen = r * 0.28;
    final bR = r * 1.45;
    final bPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.35)
      ..strokeWidth = 0.9;

    for (final corner in [
      [c.dx - bR, c.dy - bR, 1.0, 1.0],
      [c.dx + bR, c.dy - bR, -1.0, 1.0],
      [c.dx - bR, c.dy + bR, 1.0, -1.0],
      [c.dx + bR, c.dy + bR, -1.0, -1.0],
    ]) {
      canvas.drawLine(Offset(corner[0], corner[1]),
          Offset(corner[0] + corner[2] * bLen, corner[1]), bPaint);
      canvas.drawLine(Offset(corner[0], corner[1]),
          Offset(corner[0], corner[1] + corner[3] * bLen), bPaint);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.scanProgress != scanProgress || old.glowOpacity != glowOpacity;
}
