import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Animated sword duel visualization for Scenario Battle mode.
/// Two warrior figures attack each other based on progress.
class DuelAnimation extends StatefulWidget {
  final double playerProgress; // 0.0 to 1.0
  final double opponentProgress; // 0.0 to 1.0
  final Color playerColor;
  final Color opponentColor;

  const DuelAnimation({
    super.key,
    required this.playerProgress,
    required this.opponentProgress,
    this.playerColor = AppTheme.accentCyan,
    this.opponentColor = AppTheme.accentMagenta,
  });

  @override
  State<DuelAnimation> createState() => _DuelAnimationState();
}

class _DuelAnimationState extends State<DuelAnimation>
    with TickerProviderStateMixin {
  late AnimationController _idleCtrl;
  late AnimationController _attackCtrl;
  bool _playerAttacking = false;
  bool _opponentAttacking = false;
  double _prevPlayerProgress = 0;
  double _prevOpponentProgress = 0;

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _attackCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _attackCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _attackCtrl.reverse();
      }
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _playerAttacking = false;
          _opponentAttacking = false;
        });
      }
    });

    _prevPlayerProgress = widget.playerProgress;
    _prevOpponentProgress = widget.opponentProgress;
  }

  @override
  void didUpdateWidget(DuelAnimation old) {
    super.didUpdateWidget(old);
    // Detect score changes and trigger attack animation
    if (widget.playerProgress > _prevPlayerProgress + 0.01) {
      _playerAttacking = true;
      _opponentAttacking = false;
      _attackCtrl
        ..reset()
        ..forward();
    } else if (widget.opponentProgress > _prevOpponentProgress + 0.01) {
      _opponentAttacking = true;
      _playerAttacking = false;
      _attackCtrl
        ..reset()
        ..forward();
    }
    _prevPlayerProgress = widget.playerProgress;
    _prevOpponentProgress = widget.opponentProgress;
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _attackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_idleCtrl, _attackCtrl]),
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 130),
          painter: _DuelPainter(
            playerProgress: widget.playerProgress,
            opponentProgress: widget.opponentProgress,
            idlePhase: _idleCtrl.value,
            attackPhase: _attackCtrl.value,
            playerAttacking: _playerAttacking,
            opponentAttacking: _opponentAttacking,
            playerColor: widget.playerColor,
            opponentColor: widget.opponentColor,
          ),
        );
      },
    );
  }
}

class _DuelPainter extends CustomPainter {
  final double playerProgress;
  final double opponentProgress;
  final double idlePhase;
  final double attackPhase;
  final bool playerAttacking;
  final bool opponentAttacking;
  final Color playerColor;
  final Color opponentColor;

  _DuelPainter({
    required this.playerProgress,
    required this.opponentProgress,
    required this.idlePhase,
    required this.attackPhase,
    required this.playerAttacking,
    required this.opponentAttacking,
    required this.playerColor,
    required this.opponentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final groundY = h * 0.78;

    // ── Ground line ─────────────────────────────────────
    final groundPaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(w * 0.15, groundY),
      Offset(w * 0.85, groundY),
      groundPaint,
    );

    // ── Health bars ─────────────────────────────────────
    final barW = w * 0.3;
    final barH = 6.0;
    final barY = 8.0;

    // Player health bar (left)
    _drawHealthBar(canvas, Offset(w * 0.08, barY), barW, barH,
        1.0 - opponentProgress, playerColor);
    // Opponent health bar (right, mirrored)
    _drawHealthBar(canvas, Offset(w * 0.92 - barW, barY), barW, barH,
        1.0 - playerProgress, opponentColor);

    // Labels
    _drawLabel(canvas, 'YOU', Offset(w * 0.08, barY + barH + 2), playerColor);
    _drawLabel(canvas, 'OPP', Offset(w * 0.92 - 22, barY + barH + 2), opponentColor);

    // ── Fighter positions ───────────────────────────────
    final playerX = cx - 50 + (playerAttacking ? attackPhase * 20 : 0);
    final opponentX = cx + 50 - (opponentAttacking ? attackPhase * 20 : 0);
    final idleBob = math.sin(idlePhase * math.pi) * 2;

    // Draw player fighter (left, facing right)
    _drawFighter(
      canvas, playerX, groundY + idleBob, playerColor,
      facingRight: true,
      attacking: playerAttacking,
      attackPhase: attackPhase,
    );

    // Draw opponent fighter (right, facing left)
    _drawFighter(
      canvas, opponentX, groundY - idleBob, opponentColor,
      facingRight: false,
      attacking: opponentAttacking,
      attackPhase: attackPhase,
    );

    // ── Hit effect ──────────────────────────────────────
    if (attackPhase > 0.3 && attackPhase < 0.8) {
      final hitColor = playerAttacking ? playerColor : opponentColor;
      final hitX = playerAttacking ? opponentX - 10 : playerX + 10;
      final hitY = groundY - 20;
      _drawHitEffect(canvas, Offset(hitX, hitY), hitColor, attackPhase);
    }

    // ── Clash sparks at center ──────────────────────────
    if ((playerProgress > 0 || opponentProgress > 0) && !playerAttacking && !opponentAttacking) {
      final sparkAlpha = (math.sin(idlePhase * math.pi * 2) * 40 + 20).round().clamp(0, 60);
      final sparkPaint = Paint()
        ..color = const Color(0xFFF59E0B).withAlpha(sparkAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(cx, groundY - 18), 3, sparkPaint);
    }
  }

  void _drawFighter(Canvas canvas, double x, double groundY, Color color,
      {required bool facingRight, required bool attacking, required double attackPhase}) {
    final dir = facingRight ? 1.0 : -1.0;
    final bodyPaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final headY = groundY - 42;
    final bodyTopY = groundY - 35;
    final bodyBotY = groundY - 15;

    // Head
    canvas.drawCircle(Offset(x, headY), 6, bodyPaint);

    // Body
    canvas.drawLine(Offset(x, bodyTopY), Offset(x, bodyBotY), bodyPaint);

    // Legs
    canvas.drawLine(Offset(x, bodyBotY), Offset(x - 8 * dir, groundY), bodyPaint);
    canvas.drawLine(Offset(x, bodyBotY), Offset(x + 6 * dir, groundY), bodyPaint);

    // Sword arm — swings on attack
    final swordAngle = attacking ? -math.pi / 4 + attackPhase * math.pi / 2 : -math.pi / 6;
    final armEndX = x + math.cos(swordAngle) * 14 * dir;
    final armEndY = bodyTopY + 6 + math.sin(swordAngle) * 14;

    canvas.drawLine(Offset(x, bodyTopY + 6), Offset(armEndX, armEndY), bodyPaint);

    // Sword blade
    final swordPaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final bladeEndX = armEndX + math.cos(swordAngle) * 16 * dir;
    final bladeEndY = armEndY + math.sin(swordAngle) * 16;
    canvas.drawLine(Offset(armEndX, armEndY), Offset(bladeEndX, bladeEndY), swordPaint);

    // Shield arm (opposite direction)
    canvas.drawLine(
      Offset(x, bodyTopY + 6),
      Offset(x - 10 * dir, bodyTopY + 14),
      bodyPaint,
    );

    // Shield
    final shieldPaint = Paint()
      ..color = color.withAlpha(80)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x - 12 * dir, bodyTopY + 14), 5, shieldPaint);
    final shieldBorder = Paint()
      ..color = color.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(x - 12 * dir, bodyTopY + 14), 5, shieldBorder);

    // Fighter glow
    final glowPaint = Paint()
      ..color = color.withAlpha(20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(x, groundY - 25), 20, glowPaint);
  }

  void _drawHitEffect(Canvas canvas, Offset center, Color color, double phase) {
    final intensity = math.sin(phase * math.pi);
    // Spark burst
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * math.pi * 2 + phase * math.pi;
      final dist = 8 + intensity * 12;
      final sparkEnd = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      final sparkPaint = Paint()
        ..color = color.withAlpha((intensity * 200).round())
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, sparkEnd, sparkPaint);
    }

    // Central flash
    final flashPaint = Paint()
      ..color = Colors.white.withAlpha((intensity * 150).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, 4 * intensity, flashPaint);
  }

  void _drawHealthBar(Canvas canvas, Offset pos, double w, double h,
      double fill, Color color) {
    // Background
    final bgPaint = Paint()..color = const Color(0xFF1F2937);
    canvas.drawRRect(
      RRect.fromLTRBR(pos.dx, pos.dy, pos.dx + w, pos.dy + h, const Radius.circular(3)),
      bgPaint,
    );

    // Fill
    final fillW = w * fill.clamp(0.0, 1.0);
    if (fillW > 0) {
      final fillColor = fill > 0.5 ? color : (fill > 0.25 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
      final fillPaint = Paint()..color = fillColor;
      canvas.drawRRect(
        RRect.fromLTRBR(pos.dx, pos.dy, pos.dx + fillW, pos.dy + h, const Radius.circular(3)),
        fillPaint,
      );
    }

    // Border
    final borderPaint = Paint()
      ..color = color.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(
      RRect.fromLTRBR(pos.dx, pos.dy, pos.dx + w, pos.dy + h, const Radius.circular(3)),
      borderPaint,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color.withAlpha(160),
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _DuelPainter old) =>
      old.playerProgress != playerProgress ||
      old.opponentProgress != opponentProgress ||
      old.idlePhase != idlePhase ||
      old.attackPhase != attackPhase ||
      old.playerAttacking != playerAttacking ||
      old.opponentAttacking != opponentAttacking;
}
