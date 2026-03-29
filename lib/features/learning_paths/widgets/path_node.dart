import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

enum StageStatus { completed, current, locked }

class PathNode extends StatelessWidget {
  final String stageName;
  final int challengeCount;
  final int xpReward;
  final StageStatus status;
  final Color zoneColor;
  final double pulseValue;

  const PathNode({
    super.key,
    required this.stageName,
    required this.challengeCount,
    required this.xpReward,
    required this.status,
    required this.zoneColor,
    required this.pulseValue,
  });

  static const Color _green = Color(0xFF22C55E);
  static const Color _cyan = Color(0xFF3B82F6);

  Color get _nodeColor {
    switch (status) {
      case StageStatus.completed:
        return _green;
      case StageStatus.current:
        return _cyan;
      case StageStatus.locked:
        return Colors.white.withOpacity(0.15);
    }
  }

  double get _nodeOpacity {
    switch (status) {
      case StageStatus.completed:
        return 1.0;
      case StageStatus.current:
        return 1.0;
      case StageStatus.locked:
        return 0.4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: status == StageStatus.locked
                    ? [
                        Colors.white.withOpacity(0.03),
                        Colors.white.withOpacity(0.01),
                      ]
                    : [
                        zoneColor.withOpacity(0.1),
                        zoneColor.withOpacity(0.03),
                      ],
              ),
              border: Border.all(
                color: status == StageStatus.current
                    ? _cyan.withOpacity(0.4 + pulseValue * 0.4)
                    : status == StageStatus.completed
                        ? _green.withOpacity(0.3)
                        : Colors.white.withOpacity(0.05),
                width: status == StageStatus.current ? 1.5 : 1,
              ),
              boxShadow: [
                if (status == StageStatus.current)
                  BoxShadow(
                    color: _cyan.withOpacity(0.15 + pulseValue * 0.15),
                    blurRadius: 16 + pulseValue * 8,
                    spreadRadius: pulseValue * 2,
                  ),
                if (status == StageStatus.completed)
                  BoxShadow(
                    color: _green.withOpacity(0.1),
                    blurRadius: 12,
                  ),
              ],
            ),
            child: Row(
              children: [
                // Node circle
                _buildNodeCircle(),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stageName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(_nodeOpacity),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Challenge count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: zoneColor.withOpacity(
                                status == StageStatus.locked ? 0.05 : 0.12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.extension,
                                  size: 10,
                                  color: zoneColor.withOpacity(
                                    status == StageStatus.locked ? 0.3 : 0.8,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$challengeCount',
                                  style: TextStyle(
                                    color: zoneColor.withOpacity(
                                      status == StageStatus.locked ? 0.3 : 0.8,
                                    ),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // XP reward
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                size: 12,
                                color: Colors.amber.withOpacity(
                                  status == StageStatus.locked ? 0.2 : 0.7,
                                ),
                              ),
                              Text(
                                '$xpReward XP',
                                style: TextStyle(
                                  color: Colors.amber.withOpacity(
                                    status == StageStatus.locked ? 0.2 : 0.7,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status icon
                if (status == StageStatus.completed)
                  const Icon(Icons.check_circle, color: _green, size: 20),
                if (status == StageStatus.locked)
                  Icon(Icons.lock, color: Colors.white.withOpacity(0.15), size: 18),
                if (status == StageStatus.current)
                  Icon(
                    Icons.play_circle_fill,
                    color: _cyan.withOpacity(0.7 + pulseValue * 0.3),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeCircle() {
    final double scale = status == StageStatus.current
        ? 1.0 + pulseValue * 0.08
        : 1.0;

    return Transform.scale(
      scale: scale,
      child: CustomPaint(
        size: const Size(36, 36),
        painter: _NodeCirclePainter(
          color: _nodeColor,
          status: status,
          pulseValue: pulseValue,
        ),
      ),
    );
  }
}

class _NodeCirclePainter extends CustomPainter {
  final Color color;
  final StageStatus status;
  final double pulseValue;

  _NodeCirclePainter({
    required this.color,
    required this.status,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer glow
    if (status != StageStatus.locked) {
      canvas.drawCircle(
        center,
        radius + 4,
        Paint()
          ..color = color.withOpacity(status == StageStatus.current
              ? 0.15 + pulseValue * 0.15
              : 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(status == StageStatus.locked ? 0.05 : 0.2),
            color.withOpacity(status == StageStatus.locked ? 0.02 : 0.05),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Border ring
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withOpacity(status == StageStatus.locked ? 0.1 : 0.6),
    );

    // Inner dot for current
    if (status == StageStatus.current) {
      canvas.drawCircle(
        center,
        4 + pulseValue * 2,
        Paint()
          ..color = color.withOpacity(0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Checkmark for completed
    if (status == StageStatus.completed) {
      final checkPaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(center.dx - 6, center.dy);
      path.lineTo(center.dx - 2, center.dy + 5);
      path.lineTo(center.dx + 7, center.dy - 5);
      canvas.drawPath(path, checkPaint);
    }

    // Lock icon for locked
    if (status == StageStatus.locked) {
      final lockPaint = Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Lock body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, center.dy + 2), width: 10, height: 8),
          const Radius.circular(2),
        ),
        lockPaint,
      );
      // Lock arc
      final arcRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy - 2),
        width: 8,
        height: 8,
      );
      canvas.drawArc(arcRect, pi, pi, false, lockPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NodeCirclePainter old) =>
      old.pulseValue != pulseValue;
}
