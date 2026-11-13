import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';

/// Animated radar pulses shown while searching for drivers.
class SearchRadar extends StatefulWidget {
  const SearchRadar({super.key, this.size = 220, this.active = true, this.child});
  final double size;
  final bool active;
  final Widget? child;

  @override
  State<SearchRadar> createState() => _SearchRadarState();
}

class _SearchRadarState extends State<SearchRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant SearchRadar old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => CustomPaint(painter: _RadarPainter(_c.value, widget.active), child: child),
        child: Center(
          child: Container(
            width: widget.size * 0.3,
            height: widget.size * 0.3,
            decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle, boxShadow: AppShadows.brand),
            child: widget.child ?? const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.active);
  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.crimson.withValues(alpha: 0.12);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(c, maxR * i / 3, ring);
    }
    if (!active) return;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = maxR * (0.18 + 0.82 * p);
      canvas.drawCircle(c, r, Paint()..color = AppColors.crimson.withValues(alpha: 0.18 * (1 - p)));
    }
    // Sweep
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 2,
        colors: [AppColors.crimson.withValues(alpha: 0), AppColors.crimson.withValues(alpha: 0.25)],
        transform: GradientRotation(2 * math.pi * t - math.pi / 2),
      ).createShader(Rect.fromCircle(center: c, radius: maxR));
    canvas.drawArc(Rect.fromCircle(center: c, radius: maxR), 2 * math.pi * t - math.pi / 2, math.pi / 2, true, sweep);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t || old.active != active;
}
