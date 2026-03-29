import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Animated cage-trap visualization for Mind Trap mode.
/// Cage bars close in as opponent scores; break away as player scores.
class TrapAnimation extends StatefulWidget {
  final double playerProgress; // 0.0 to 1.0 — more = escaping
  final double opponentProgress; // 0.0 to 1.0 — more = trapped
  final Color playerColor;
  final Color opponentColor;

  const TrapAnimation({
    super.key,
    required this.playerProgress,
    required this.opponentProgress,
    this.playerColor = AppTheme.accentPurple,
    this.opponentColor = AppTheme.accentMagenta,
  });

  @override
  State<TrapAnimation> createState() => _TrapAnimationState();
}

class _TrapAnimationState extends State<TrapAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _trapCtrl;
  late Animation<double> _trapAnim;

  double _prevTrapLevel = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _trapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final level = _calcTrapLevel();
    _trapAnim = Tween(begin: 0.0, end: level)
        .animate(CurvedAnimation(parent: _trapCtrl, curve: Curves.easeOutCubic));
    _trapCtrl.forward();
    _prevTrapLevel = level;
  }

  double _calcTrapLevel() {
    // trap level: opponent winning = more trapped (0 to 1)
    final net = widget.opponentProgress - widget.playerProgress * 0.7;
    return net.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(TrapAnimation old) {
    super.didUpdateWidget(old);
    final newLevel = _calcTrapLevel();
    if ((newLevel - _prevTrapLevel).abs() > 0.01) {
      _trapAnim = Tween(begin: _prevTrapLevel, end: newLevel)
          .animate(CurvedAnimation(parent: _trapCtrl, curve: Curves.easeOutCubic));
      _trapCtrl
        ..reset()
        ..forward();
      _prevTrapLevel = newLevel;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _trapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_trapAnim, _pulseCtrl]),
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 130),
          painter: _TrapPainter(
            trapLevel: _trapAnim.value,
            pulsePhase: _pulseCtrl.value,
            playerProgress: widget.playerProgress,
            opponentProgress: widget.opponentProgress,
            playerColor: widget.playerColor,
            opponentColor: widget.opponentColor,
          ),
        );
      },
    );
  }
}

class _TrapPainter extends CustomPainter {
  final double trapLevel; // 0 = free, 1 = fully trapped
  final double pulsePhase;
  final double playerProgress;
  final double opponentProgress;
  final Color playerColor;
  final Color opponentColor;

  _TrapPainter({
    required this.trapLevel,
    required this.pulsePhase,
    required this.playerProgress,
    required this.opponentProgress,
    required this.playerColor,
    required this.opponentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── Background glow ─────────────────────────────────
    final glowColor = trapLevel > 0.5 ? opponentColor : playerColor;
    final glowPaint = Paint()
      ..color = glowColor.withAlpha((20 + 20 * pulsePhase).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset(cx, cy), 40, glowPaint);

    // ── Floor shadow ────────────────────────────────────
    final floorPaint = Paint()
      ..color = const Color(0xFF1F2937).withAlpha(100)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 38), width: 60, height: 10),
      floorPaint,
    );

    // ── Stick figure ────────────────────────────────────
    final figureColor = trapLevel > 0.6
        ? opponentColor.withAlpha(200)
        : playerColor.withAlpha(220);
    final figurePaint = Paint()
      ..color = figureColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Head
    canvas.drawCircle(Offset(cx, cy - 18), 7, figurePaint);

    // Body
    canvas.drawLine(Offset(cx, cy - 11), Offset(cx, cy + 10), figurePaint);

    // Arms — raised if trapped, relaxed if free
    final armAngle = trapLevel * 0.5; // 0 = down, 0.5 = up
    final leftArmEnd = Offset(
      cx - 14 + armAngle * 4,
      cy - 4 + (1 - armAngle) * 10 - armAngle * 8,
    );
    final rightArmEnd = Offset(
      cx + 14 - armAngle * 4,
      cy - 4 + (1 - armAngle) * 10 - armAngle * 8,
    );
    canvas.drawLine(Offset(cx, cy - 4), leftArmEnd, figurePaint);
    canvas.drawLine(Offset(cx, cy - 4), rightArmEnd, figurePaint);

    // Legs
    canvas.drawLine(Offset(cx, cy + 10), Offset(cx - 10, cy + 28), figurePaint);
    canvas.drawLine(Offset(cx, cy + 10), Offset(cx + 10, cy + 28), figurePaint);

    // ── Cage bars ───────────────────────────────────────
    final barCount = 8;
    final cageRadius = 28.0;
    final barHeight = 55.0;
    final barTopY = cy - 28;

    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * math.pi * 2;

      // Bars drop down based on trap level
      // Each bar has its own threshold for appearing
      final barThreshold = i / barCount;
      final barVisible = trapLevel > barThreshold * 0.8;
      if (!barVisible) continue;

      final barAlpha = ((trapLevel - barThreshold * 0.8) / 0.3).clamp(0.0, 1.0);

      // Bar position — forms a circle around the figure
      final bx = cx + math.cos(angle) * cageRadius;
      final topY = barTopY - (1 - barAlpha) * 30; // Drops from above

      // Check if this bar is "broken" by player progress
      final brokenThreshold = (i / barCount);
      final isBroken = playerProgress > 0.3 && brokenThreshold < playerProgress * 0.5;

      if (isBroken) {
        // Broken bar fragments
        final fragmentPaint = Paint()
          ..color = playerColor.withAlpha(60)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

        // Two small fragments
        canvas.drawLine(
          Offset(bx - 2, topY + barHeight * 0.3),
          Offset(bx - 6, topY + barHeight * 0.5),
          fragmentPaint,
        );
        canvas.drawLine(
          Offset(bx + 2, topY + barHeight * 0.6),
          Offset(bx + 5, topY + barHeight * 0.8),
          fragmentPaint,
        );
        continue;
      }

      final barPaint = Paint()
        ..color = opponentColor.withAlpha((barAlpha * 180).round())
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(bx, topY),
        Offset(bx, topY + barHeight),
        barPaint,
      );
    }

    // ── Cage top ring ───────────────────────────────────
    if (trapLevel > 0.2) {
      final ringAlpha = ((trapLevel - 0.2) / 0.3).clamp(0.0, 1.0);
      final ringPaint = Paint()
        ..color = opponentColor.withAlpha((ringAlpha * 120).round())
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, barTopY),
          width: cageRadius * 2,
          height: cageRadius * 0.6,
        ),
        ringPaint,
      );
    }

    // ── Status text ─────────────────────────────────────
    final statusText = trapLevel > 0.7
        ? 'TRAPPED!'
        : trapLevel > 0.3
            ? 'Danger...'
            : playerProgress > opponentProgress
                ? 'Escaping!'
                : 'Safe';
    final statusColor = trapLevel > 0.7
        ? opponentColor
        : trapLevel > 0.3
            ? const Color(0xFFF59E0B)
            : playerColor;

    final tp = TextPainter(
      text: TextSpan(
        text: statusText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: statusColor.withAlpha(180),
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, h - 16));
  }

  @override
  bool shouldRepaint(covariant _TrapPainter old) =>
      old.trapLevel != trapLevel ||
      old.pulsePhase != pulsePhase ||
      old.playerProgress != playerProgress ||
      old.opponentProgress != opponentProgress;
}
