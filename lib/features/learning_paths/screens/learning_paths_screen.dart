import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/path_node.dart';

class LearningPathsScreen extends StatefulWidget {
  const LearningPathsScreen({super.key});

  @override
  State<LearningPathsScreen> createState() => _LearningPathsScreenState();
}

class _LearningPathsScreenState extends State<LearningPathsScreen>
    with TickerProviderStateMixin {
  static const Color _bgColor = Color(0xFF111827);
  static const Color _cyan = Color(0xFF3B82F6);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _magenta = Color(0xFFEF4444);
  static const Color _green = Color(0xFF22C55E);

  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late ScrollController _scrollController;

  final List<_Zone> _zones = [
    _Zone(
      name: 'Novice Valley',
      subtitle: 'Master the fundamentals',
      icon: Icons.park,
      color: const Color(0xFF22C55E),
      secondaryColor: const Color(0xFF00CC66),
      requiredLeague: 'None',
      progress: 1.0,
      stages: [
        _Stage('Variables & Types', 5, 100, StageStatus.completed),
        _Stage('Control Flow', 4, 120, StageStatus.completed),
        _Stage('Functions', 6, 150, StageStatus.completed),
        _Stage('Arrays & Lists', 5, 130, StageStatus.completed),
        _Stage('String Mastery', 4, 140, StageStatus.completed),
      ],
    ),
    _Zone(
      name: 'Logic Forest',
      subtitle: 'Sharpen your logical mind',
      icon: Icons.account_tree,
      color: const Color(0xFF3B82F6),
      secondaryColor: const Color(0xFF0088CC),
      requiredLeague: 'Bronze',
      progress: 0.75,
      stages: [
        _Stage('Boolean Logic', 4, 160, StageStatus.completed),
        _Stage('Pattern Matching', 5, 180, StageStatus.completed),
        _Stage('Recursion Basics', 6, 200, StageStatus.completed),
        _Stage('Data Structures', 7, 250, StageStatus.current),
        _Stage('Graph Theory', 6, 280, StageStatus.locked),
        _Stage('Logic Puzzles', 5, 220, StageStatus.locked),
      ],
    ),
    _Zone(
      name: 'Algorithm Desert',
      subtitle: 'Conquer algorithmic challenges',
      icon: Icons.landscape,
      color: const Color(0xFFFFAA00),
      secondaryColor: const Color(0xFFFF8800),
      requiredLeague: 'Silver',
      progress: 0.0,
      stages: [
        _Stage('Sorting Algorithms', 6, 300, StageStatus.locked),
        _Stage('Search Algorithms', 5, 280, StageStatus.locked),
        _Stage('Dynamic Programming', 8, 400, StageStatus.locked),
        _Stage('Greedy Algorithms', 6, 350, StageStatus.locked),
        _Stage('Divide & Conquer', 7, 380, StageStatus.locked),
      ],
    ),
    _Zone(
      name: 'AI Citadel',
      subtitle: 'Enter the realm of intelligence',
      icon: Icons.psychology,
      color: const Color(0xFF8B5CF6),
      secondaryColor: const Color(0xFF8800CC),
      requiredLeague: 'Gold',
      progress: 0.0,
      stages: [
        _Stage('ML Fundamentals', 5, 400, StageStatus.locked),
        _Stage('Neural Networks', 7, 500, StageStatus.locked),
        _Stage('NLP Basics', 6, 450, StageStatus.locked),
        _Stage('Computer Vision', 8, 550, StageStatus.locked),
        _Stage('Reinforcement Learning', 9, 600, StageStatus.locked),
      ],
    ),
    _Zone(
      name: 'Grandmaster Summit',
      subtitle: 'Ascend to legendary status',
      icon: Icons.auto_awesome,
      color: const Color(0xFFF59E0B),
      secondaryColor: const Color(0xFFEF4444),
      requiredLeague: 'Diamond',
      progress: 0.0,
      stages: [
        _Stage('System Design', 10, 800, StageStatus.locked),
        _Stage('Competitive Coding', 8, 700, StageStatus.locked),
        _Stage('Open Source Contrib', 6, 600, StageStatus.locked),
        _Stage('Final Boss: Hackathon', 1, 2000, StageStatus.locked),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Animated background particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _BackgroundParticlePainter(
                  progress: _particleController.value,
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 40),
                    itemCount: _zones.length,
                    itemBuilder: (context, zoneIndex) {
                      return _buildZoneSection(zoneIndex);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_cyan, _purple, _magenta],
              ).createShader(bounds),
              child: const Text(
                'Learning Journey',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          _buildOverallProgress(),
        ],
      ),
    );
  }

  Widget _buildOverallProgress() {
    final totalStages = _zones.fold<int>(0, (s, z) => s + z.stages.length);
    final completedStages = _zones.fold<int>(
      0,
      (s, z) => s + z.stages.where((st) => st.status == StageStatus.completed).length,
    );
    final pct = totalStages > 0 ? completedStages / totalStages : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(_cyan),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(pct * 100).toInt()}%',
                style: const TextStyle(
                  color: _cyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneSection(int zoneIndex) {
    final zone = _zones[zoneIndex];
    final isLastZone = zoneIndex == _zones.length - 1;

    return Column(
      children: [
        // Zone header
        _buildZoneHeader(zone, zoneIndex),
        // Path with nodes
        SizedBox(
          width: double.infinity,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _particleController]),
            builder: (context, _) {
              return CustomPaint(
                painter: _ZonePathPainter(
                  zone: zone,
                  pulseValue: _pulseController.value,
                  particleValue: _particleController.value,
                  isLastZone: isLastZone,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (int i = 0; i < zone.stages.length; i++)
                        _buildStageNode(zone, i),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!isLastZone)
          _buildZoneConnector(zone.color, _zones[zoneIndex + 1].color),
      ],
    );
  }

  Widget _buildZoneHeader(_Zone zone, int index) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatOffset = sin(_floatController.value * pi * 2 + index * 0.5) * 4;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    zone.color.withOpacity(0.15),
                    zone.secondaryColor.withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: zone.color.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: zone.color.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Zone icon with glow
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          zone.color.withOpacity(0.3),
                          zone.color.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: zone.color.withOpacity(0.3),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Icon(zone.icon, color: zone.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: TextStyle(
                            color: zone.color,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            shadows: [
                              Shadow(color: zone.color.withOpacity(0.5), blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          zone.subtitle,
                          style: TextStyle(
                            color: zone.color.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: zone.progress,
                                  backgroundColor: Colors.white.withOpacity(0.06),
                                  valueColor: AlwaysStoppedAnimation(zone.color),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(zone.progress * 100).toInt()}%',
                              style: TextStyle(
                                color: zone.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // League badge
                  if (zone.requiredLeague != 'None')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: zone.color.withOpacity(0.12),
                        border: Border.all(color: zone.color.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.military_tech, color: Colors.white54, size: 14),
                          Text(
                            zone.requiredLeague,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageNode(_Zone zone, int stageIndex) {
    final stage = zone.stages[stageIndex];
    final isLeft = stageIndex.isEven;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (!isLeft) const Spacer(),
          if (!isLeft)
            SizedBox(
              width: 50,
              child: CustomPaint(
                painter: _ConnectorLinePainter(
                  color: zone.color,
                  fromRight: true,
                  isActive: stage.status != StageStatus.locked,
                ),
                size: const Size(50, 2),
              ),
            ),
          PathNode(
            stageName: stage.name,
            challengeCount: stage.challengeCount,
            xpReward: stage.xpReward,
            status: stage.status,
            zoneColor: zone.color,
            pulseValue: _pulseController.value,
          ),
          if (isLeft)
            SizedBox(
              width: 50,
              child: CustomPaint(
                painter: _ConnectorLinePainter(
                  color: zone.color,
                  fromRight: false,
                  isActive: stage.status != StageStatus.locked,
                ),
                size: const Size(50, 2),
              ),
            ),
          if (isLeft) const Spacer(),
        ],
      ),
    );
  }

  Widget _buildZoneConnector(Color fromColor, Color toColor) {
    return Container(
      height: 50,
      width: 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fromColor.withOpacity(0.5), toColor.withOpacity(0.5)],
        ),
        boxShadow: [
          BoxShadow(color: fromColor.withOpacity(0.3), blurRadius: 8),
        ],
      ),
    );
  }
}

// ── Data Models ──

class _Stage {
  final String name;
  final int challengeCount;
  final int xpReward;
  final StageStatus status;

  const _Stage(this.name, this.challengeCount, this.xpReward, this.status);
}

class _Zone {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color secondaryColor;
  final String requiredLeague;
  final double progress;
  final List<_Stage> stages;

  const _Zone({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.secondaryColor,
    required this.requiredLeague,
    required this.progress,
    required this.stages,
  });
}

// ── Custom Painters ──

class _BackgroundParticlePainter extends CustomPainter {
  final double progress;

  _BackgroundParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(99);
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFF22C55E),
      const Color(0xFFEF4444),
    ];

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = (baseY + progress * size.height * 0.3 * (random.nextBool() ? 1 : -1)) %
          size.height;
      final color = colors[i % colors.length];
      final opacity = 0.05 + random.nextDouble() * 0.12;
      final radius = 1.0 + random.nextDouble() * 2.5;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundParticlePainter old) =>
      old.progress != progress;
}

class _ZonePathPainter extends CustomPainter {
  final _Zone zone;
  final double pulseValue;
  final double particleValue;
  final bool isLastZone;

  _ZonePathPainter({
    required this.zone,
    required this.pulseValue,
    required this.particleValue,
    required this.isLastZone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw vertical connecting line through center-ish area
    final lineX = size.width * 0.5;
    final paint = Paint()
      ..color = zone.color.withOpacity(0.08)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(lineX, 0),
      Offset(lineX, size.height),
      paint,
    );

    // Glowing dots along the line for active zones
    if (zone.progress > 0) {
      final dotCount = (size.height / 30).floor();
      for (int i = 0; i < dotCount; i++) {
        final y = i * 30.0;
        final animOffset = (particleValue * 30 + i * 5) % 30;
        final opacity = 0.1 + 0.15 * sin((particleValue + i * 0.1) * pi * 2).abs();

        canvas.drawCircle(
          Offset(lineX, y + animOffset),
          2,
          Paint()
            ..color = zone.color.withOpacity(opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ZonePathPainter old) => true;
}

class _ConnectorLinePainter extends CustomPainter {
  final Color color;
  final bool fromRight;
  final bool isActive;

  _ConnectorLinePainter({
    required this.color,
    required this.fromRight,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: fromRight ? Alignment.centerRight : Alignment.centerLeft,
        end: fromRight ? Alignment.centerLeft : Alignment.centerRight,
        colors: [
          color.withOpacity(isActive ? 0.5 : 0.08),
          color.withOpacity(isActive ? 0.1 : 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (fromRight) {
      path.moveTo(size.width, size.height / 2);
      path.quadraticBezierTo(
        size.width * 0.3,
        size.height / 2,
        0,
        size.height / 2,
      );
    } else {
      path.moveTo(0, size.height / 2);
      path.quadraticBezierTo(
        size.width * 0.7,
        size.height / 2,
        size.width,
        size.height / 2,
      );
    }
    canvas.drawPath(path, paint);

    // Glow
    if (isActive) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.15)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorLinePainter old) => false;
}
