import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// A small pulsing dot — the "live"/online indicator convention (camera
/// status, active monitoring feed, etc.).
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulseDot({super.key, this.color = AppColors.accent, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6 * _scale.value),
              blurRadius: widget.size * _scale.value,
              spreadRadius: widget.size * 0.15 * _scale.value,
            ),
          ],
        ),
      ),
    );
  }
}
