import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';

/// A circular countdown timer with neon ring that depletes, color transitions
/// (cyan -> yellow -> red), and a pulse animation when under 10 seconds.
class BattleTimerWidget extends StatefulWidget {
  /// Total duration in seconds.
  final int totalSeconds;

  /// Callback fired every second with remaining time.
  final ValueChanged<int>? onTick;

  /// Callback when timer reaches zero.
  final VoidCallback? onComplete;

  /// Diameter of the timer circle.
  final double size;

  /// Stroke width of the neon ring.
  final double strokeWidth;

  /// Optional label shown below the time.
  final String? label;

  const BattleTimerWidget({
    super.key,
    required this.totalSeconds,
    this.onTick,
    this.onComplete,
    this.size = 80,
    this.strokeWidth = 5,
    this.label,
  });

  @override
  State<BattleTimerWidget> createState() => _BattleTimerWidgetState();
}

class _BattleTimerWidgetState extends State<BattleTimerWidget>
    with TickerProviderStateMixin {
  late final AnimationController _timerController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;

    // Main countdown controller
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    );

    _timerController.addListener(() {
      final newRemaining =
          (widget.totalSeconds * (1 - _timerController.value)).ceil();
      if (newRemaining != _remaining) {
        setState(() => _remaining = newRemaining);
        widget.onTick?.call(_remaining);

        // Start pulse when < 10 seconds
        if (_remaining <= 10 && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }

        if (_remaining <= 0) {
          widget.onComplete?.call();
        }
      }
    });

    // Pulse animation for urgency
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timerController.forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Returns a color based on remaining time fraction:
  /// cyan (>50%) -> yellow (20-50%) -> red (<20%).
  Color _getTimerColor(double fraction) {
    if (fraction > 0.5) return AppTheme.accentCyan;
    if (fraction > 0.2) {
      // Lerp cyan -> yellow
      final t = (0.5 - fraction) / 0.3;
      return Color.lerp(AppTheme.accentCyan, AppTheme.accentGold, t)!;
    }
    // Lerp yellow -> red
    final t = (0.2 - fraction) / 0.2;
    return Color.lerp(AppTheme.accentGold, AppTheme.accentMagenta, t)!;
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_timerController, _pulse]),
      builder: (context, _) {
        final fraction = 1 - _timerController.value;
        final color = _getTimerColor(fraction);
        final isPulsing = _remaining <= 10;

        return Transform.scale(
          scale: isPulsing ? _pulse.value : 1.0,
          child: SizedBox(
            width: widget.size,
            height: widget.size + (widget.label != null ? 18 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _TimerRingPainter(
                      fraction: fraction,
                      color: color,
                      strokeWidth: widget.strokeWidth,
                      glowIntensity: isPulsing ? _pulse.value : 0.6,
                    ),
                    child: Center(
                      child: Text(
                        _formatTime(_remaining),
                        style: AppTheme.headerStyle(
                          fontSize: widget.size * 0.24,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.label != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.label!,
                    style: AppTheme.bodyStyle(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Timer Ring Painter ──────────────────────────────────────────────

class _TimerRingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final double strokeWidth;
  final double glowIntensity;

  _TimerRingPainter({
    required this.fraction,
    required this.color,
    required this.strokeWidth,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth * 2) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (dark background ring)
    final trackPaint = Paint()
      ..color = AppTheme.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Glow layer
    final glowPaint = Paint()
      ..color = color.withAlpha((40 * glowIntensity).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * fraction,
      false,
      glowPaint,
    );

    // Main neon arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * fraction,
      false,
      arcPaint,
    );

    // Bright cap at the leading edge
    if (fraction > 0.01) {
      final capAngle = -pi / 2 + 2 * pi * fraction;
      final capX = center.dx + radius * cos(capAngle);
      final capY = center.dy + radius * sin(capAngle);
      final capPaint = Paint()
        ..color = Colors.white.withAlpha(180)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(capX, capY), strokeWidth * 0.6, capPaint);
    }
  }

  @override
  bool shouldRepaint(_TimerRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}
