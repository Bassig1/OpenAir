import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/openair_theme.dart';

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.subtitle,
    this.size,
  });

  final String label;
  final double value;
  final double max;
  final Color color;
  final String? subtitle;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final colors = OpenAirColors.of(context);
    final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final ringSize = size ?? 100.0;
    return SizedBox(
      width: ringSize,
      child: Column(
        children: [
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: color,
                trackColor: colors.border,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      value % 1 == 0
                          ? value.toStringAsFixed(0)
                          : value.toStringAsFixed(1),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.0,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
