import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Animated racing visualization for Speed Solve mode.
/// Two cars race across a track based on player/opponent progress.
class RaceAnimation extends StatefulWidget {
  final double playerProgress; // 0.0 to 1.0
  final double opponentProgress; // 0.0 to 1.0
  final Color playerColor;
  final Color opponentColor;

  const RaceAnimation({
    super.key,
    required this.playerProgress,
    required this.opponentProgress,
    this.playerColor = AppTheme.accentCyan,
    this.opponentColor = AppTheme.accentMagenta,
  });

  @override
  State<RaceAnimation> createState() => _RaceAnimationState();
}

class _RaceAnimationState extends State<RaceAnimation>
    with TickerProviderStateMixin {
  late AnimationController _playerCtrl;
  late AnimationController _opponentCtrl;
  late AnimationController _dashCtrl;
  late Animation<double> _playerAnim;
  late Animation<double> _opponentAnim;

  @override
  void initState() {
    super.initState();
    _playerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opponentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _playerAnim = Tween(begin: 0.0, end: widget.playerProgress)
        .animate(CurvedAnimation(parent: _playerCtrl, curve: Curves.easeOutCubic));
    _opponentAnim = Tween(begin: 0.0, end: widget.opponentProgress)
        .animate(CurvedAnimation(parent: _opponentCtrl, curve: Curves.easeOutCubic));

    _playerCtrl.forward();
    _opponentCtrl.forward();
  }

  @override
  void didUpdateWidget(RaceAnimation old) {
    super.didUpdateWidget(old);
    if (old.playerProgress != widget.playerProgress) {
      _playerAnim = Tween(begin: _playerAnim.value, end: widget.playerProgress)
          .animate(CurvedAnimation(parent: _playerCtrl, curve: Curves.easeOutCubic));
      _playerCtrl
        ..reset()
        ..forward();
    }
    if (old.opponentProgress != widget.opponentProgress) {
      _opponentAnim = Tween(begin: _opponentAnim.value, end: widget.opponentProgress)
          .animate(CurvedAnimation(parent: _opponentCtrl, curve: Curves.easeOutCubic));
      _opponentCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _playerCtrl.dispose();
    _opponentCtrl.dispose();
    _dashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_playerAnim, _opponentAnim, _dashCtrl]),
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 130),
          painter: _RacePainter(
            playerProgress: _playerAnim.value,
            opponentProgress: _opponentAnim.value,
            dashPhase: _dashCtrl.value,
            playerColor: widget.playerColor,
            opponentColor: widget.opponentColor,
          ),
        );
      },
    );
  }
}

class _RacePainter extends CustomPainter {
  final double playerProgress;
  final double opponentProgress;
  final double dashPhase;
  final Color playerColor;
  final Color opponentColor;

  _RacePainter({
    required this.playerProgress,
    required this.opponentProgress,
    required this.dashPhase,
    required this.playerColor,
    required this.opponentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final trackMargin = 30.0;
    final trackWidth = w - trackMargin * 2;
    final lane1Y = h * 0.35;
    final lane2Y = h * 0.65;
    final laneH = 22.0;

    // ── Track background ────────────────────────────────
    final trackBg = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.fill;

    final trackRect = RRect.fromLTRBR(
      trackMargin - 4, lane1Y - laneH - 4,
      w - trackMargin + 4, lane2Y + laneH + 4,
      const Radius.circular(10),
    );
    canvas.drawRRect(trackRect, trackBg);

    // ── Lane lines (dashed center line) ─────────────────
    final lanePaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final midY = (lane1Y + lane2Y) / 2;
    const dashW = 12.0;
    const gapW = 8.0;
    final offset = dashPhase * (dashW + gapW);

    for (double x = trackMargin - offset; x < w - trackMargin; x += dashW + gapW) {
      final start = x.clamp(trackMargin, w - trackMargin);
      final end = (x + dashW).clamp(trackMargin, w - trackMargin);
      if (end > start) {
        canvas.drawLine(Offset(start, midY), Offset(end, midY), lanePaint);
      }
    }

    // ── Finish line (checkered) ─────────────────────────
    final finishX = w - trackMargin;
    const checkSize = 5.0;
    final checkBlack = Paint()..color = const Color(0xFF111827);
    final checkWhite = Paint()..color = const Color(0xFF6B7280);

    for (double y = lane1Y - laneH; y < lane2Y + laneH; y += checkSize) {
      for (double x = finishX - 10; x < finishX; x += checkSize) {
        final isBlack = ((x - finishX + 10) ~/ checkSize + (y - lane1Y + laneH) ~/ checkSize) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, checkSize, checkSize),
          isBlack ? checkBlack : checkWhite,
        );
      }
    }

    // ── Start line ──────────────────────────────────────
    final startPaint = Paint()
      ..color = const Color(0xFF6B7280)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(trackMargin, lane1Y - laneH),
      Offset(trackMargin, lane2Y + laneH),
      startPaint,
    );

    // ── Cars ────────────────────────────────────────────
    _drawCar(canvas, trackMargin, trackWidth, lane1Y, playerProgress, playerColor, true);
    _drawCar(canvas, trackMargin, trackWidth, lane2Y, opponentProgress, opponentColor, false);

    // ── Labels ──────────────────────────────────────────
    _drawLabel(canvas, 'YOU', Offset(trackMargin - 2, lane1Y - laneH - 14), playerColor);
    _drawLabel(canvas, 'OPP', Offset(trackMargin - 2, lane2Y + laneH + 2), opponentColor);
  }

  void _drawCar(Canvas canvas, double startX, double trackW, double laneY,
      double progress, Color color, bool isTop) {
    final carX = startX + trackW * progress.clamp(0.0, 0.95);
    final carW = 32.0;
    final carH = 14.0;
    final carY = laneY - carH / 2;

    // Speed lines behind car
    if (progress > 0.05) {
      final speedPaint = Paint()
        ..color = color.withAlpha(40)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final lineX = carX - 8 - i * 7;
        final lineY = carY + 3 + i * 4;
        if (lineX > startX) {
          canvas.drawLine(
            Offset(lineX, lineY),
            Offset(lineX - 10 - i * 3, lineY),
            speedPaint,
          );
        }
      }
    }

    // Car body
    final bodyPaint = Paint()..color = color;
    final bodyRect = RRect.fromLTRBR(
      carX, carY, carX + carW, carY + carH,
      const Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Cabin (top part)
    final cabinPaint = Paint()..color = color.withAlpha(180);
    final cabinRect = RRect.fromLTRBR(
      carX + 8, carY - 5, carX + 22, carY + 1,
      const Radius.circular(3),
    );
    canvas.drawRRect(cabinRect, cabinPaint);

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF111827);
    canvas.drawCircle(Offset(carX + 7, carY + carH), 3.5, wheelPaint);
    canvas.drawCircle(Offset(carX + carW - 7, carY + carH), 3.5, wheelPaint);

    // Wheel rims
    final rimPaint = Paint()..color = const Color(0xFF6B7280);
    canvas.drawCircle(Offset(carX + 7, carY + carH), 1.5, rimPaint);
    canvas.drawCircle(Offset(carX + carW - 7, carY + carH), 1.5, rimPaint);

    // Headlight
    final lightPaint = Paint()..color = const Color(0xFFFDE68A);
    canvas.drawCircle(Offset(carX + carW - 1, carY + carH / 2), 2, lightPaint);

    // Glow under car
    final glowPaint = Paint()
      ..color = color.withAlpha(30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(
      Rect.fromLTWH(carX - 2, carY + carH + 2, carW + 4, 4),
      glowPaint,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color.withAlpha(180),
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _RacePainter old) =>
      old.playerProgress != playerProgress ||
      old.opponentProgress != opponentProgress ||
      old.dashPhase != dashPhase;
}
