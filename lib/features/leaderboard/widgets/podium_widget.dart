import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class PodiumData {
  final String username;
  final String avatarPath;
  final int score;
  final String statLabel;

  const PodiumData({
    required this.username,
    required this.avatarPath,
    required this.score,
    required this.statLabel,
  });
}

class PodiumWidget extends StatefulWidget {
  final PodiumData first;
  final PodiumData second;
  final PodiumData third;

  const PodiumWidget({
    super.key,
    required this.first,
    required this.second,
    required this.third,
  });

  @override
  State<PodiumWidget> createState() => _PodiumWidgetState();
}

class _PodiumWidgetState extends State<PodiumWidget>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);
  static const Color _cyan = Color(0xFF3B82F6);

  late AnimationController _particleController;
  late AnimationController _glowController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _glowController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 310,
      child: AnimatedBuilder(
        animation: Listenable.merge([_particleController, _glowController, _slideController]),
        builder: (context, _) {
          return CustomPaint(
            painter: _PodiumPainter(
              particleProgress: _particleController.value,
              glowProgress: _glowController.value,
              slideProgress: CurvedAnimation(
                parent: _slideController,
                curve: Curves.easeOutBack,
              ).value,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // #2 - Left
                Positioned(
                  left: 10,
                  bottom: 60,
                  child: _buildPodiumAvatar(
                    widget.second,
                    _silver,
                    2,
                    _slideController,
                  ),
                ),
                // #1 - Center
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 100,
                  child: _buildPodiumAvatar(
                    widget.first,
                    _gold,
                    1,
                    _slideController,
                  ),
                ),
                // #3 - Right
                Positioned(
                  right: 10,
                  bottom: 40,
                  child: _buildPodiumAvatar(
                    widget.third,
                    _bronze,
                    3,
                    _slideController,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPodiumAvatar(
    PodiumData data,
    Color color,
    int rank,
    AnimationController slideCtrl,
  ) {
    final isFirst = rank == 1;
    final avatarSize = isFirst ? 70.0 : 56.0;
    final delay = rank == 1 ? 0.0 : (rank == 2 ? 0.15 : 0.3);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: slideCtrl,
        curve: Interval(delay, 0.7 + delay * 0.3, curve: Curves.easeOutBack),
      )),
      child: SizedBox(
        width: isFirst ? null : 100,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Crown for #1
            if (isFirst)
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -3 * sin(_glowController.value * pi * 2)),
                    child: Icon(
                      Icons.workspace_premium,
                      color: _gold,
                      size: 32,
                      shadows: [
                        Shadow(color: _gold.withOpacity(0.6), blurRadius: 12),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 4),
            // Avatar
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glowRadius = isFirst ? 12.0 + 8 * _glowController.value : 6.0;
                return Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: isFirst ? 3 : 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(isFirst ? 0.6 : 0.3),
                        blurRadius: glowRadius,
                        spreadRadius: isFirst ? 2 : 0,
                      ),
                    ],
                    gradient: RadialGradient(
                      colors: [
                        color.withOpacity(0.3),
                        color.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      data.username[0],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isFirst ? 28 : 22,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Rank badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withOpacity(0.2),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_formatScore(data.score)} ${data.statLabel}',
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatScore(int score) {
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}K';
    return score.toString();
  }
}

class _PodiumPainter extends CustomPainter {
  final double particleProgress;
  final double glowProgress;
  final double slideProgress;

  static const Color _gold = Color(0xFFF59E0B);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  _PodiumPainter({
    required this.particleProgress,
    required this.glowProgress,
    required this.slideProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawPillar(canvas, w * 0.05, h * 0.62, w * 0.3, h * 0.38, _silver, slideProgress);
    _drawPillar(canvas, w * 0.35, h * 0.48, w * 0.3, h * 0.52, _gold, slideProgress);
    _drawPillar(canvas, w * 0.65, h * 0.7, w * 0.3, h * 0.3, _bronze, slideProgress);

    // Particles for #1
    if (slideProgress > 0.8) {
      _drawParticles(canvas, Offset(w * 0.5, h * 0.4), _gold);
    }
  }

  void _drawPillar(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    Color color,
    double progress,
  ) {
    final animatedHeight = height * progress;
    final animatedY = y + height - animatedHeight;

    // Glow behind pillar
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3 * glowProgress),
          color.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(x, animatedY, width, animatedHeight));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 4, animatedY - 4, width + 8, animatedHeight + 4),
        const Radius.circular(12),
      ),
      glowPaint,
    );

    // Pillar body
    final pillarPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.25),
          color.withOpacity(0.08),
        ],
      ).createShader(Rect.fromLTWH(x, animatedY, width, animatedHeight));
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, animatedY, width, animatedHeight),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
      ),
      pillarPaint,
    );

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withOpacity(0.3);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(x, animatedY, width, animatedHeight),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
      ),
      borderPaint,
    );

    // Top highlight line
    final topLinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0),
          color.withOpacity(0.6),
          color.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(x, animatedY, width, 2));
    canvas.drawRect(Rect.fromLTWH(x, animatedY, width, 2), topLinePaint);
  }

  void _drawParticles(Canvas canvas, Offset center, Color color) {
    final random = Random(42);
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 2 * pi + particleProgress * 2 * pi;
      final dist = 30 + random.nextDouble() * 60;
      final x = center.dx + cos(angle) * dist;
      final yOffset = sin(particleProgress * pi * 2 + i) * 15;
      final y = center.dy - 30 + yOffset - particleProgress * 20;

      final opacity = (1 - ((particleProgress + i / 20) % 1)).clamp(0.0, 0.8);
      final size = 1.5 + random.nextDouble() * 2.5;

      canvas.drawCircle(
        Offset(x, y),
        size,
        Paint()
          ..color = color.withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PodiumPainter old) => true;
}
