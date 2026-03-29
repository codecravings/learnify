import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/features/battle/screens/battle_lobby_screen.dart';

/// Post-battle results screen with confetti particles, score comparison,
/// animated XP counter, and ELO rating change.
class BattleResultScreen extends StatefulWidget {
  final String battleId;
  final int playerScore;
  final int opponentScore;
  final int playerTime; // seconds
  final int opponentTime; // seconds
  final bool won;
  final int xpEarned;
  final int eloChange;
  final Color modeColor;

  const BattleResultScreen({
    super.key,
    required this.battleId,
    required this.playerScore,
    required this.opponentScore,
    required this.playerTime,
    required this.opponentTime,
    required this.won,
    required this.xpEarned,
    required this.eloChange,
    required this.modeColor,
  });

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _headerController;
  late final AnimationController _xpCountController;
  late final AnimationController _barController;
  late final AnimationController _slideUpController;

  late final Animation<double> _headerScale;
  late final Animation<double> _xpCount;
  late final Animation<double> _barFill;
  late final Animation<double> _slideUp;

  bool _showAchievement = false;

  @override
  void initState() {
    super.initState();

    // Confetti particles
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.won) {
      _confettiController.repeat();
    }

    // Header pop-in
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.elasticOut),
    );
    _headerController.forward();

    // XP counter
    _xpCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _xpCount = Tween<double>(begin: 0, end: widget.xpEarned.toDouble())
        .animate(CurvedAnimation(
      parent: _xpCountController,
      curve: Curves.easeOutCubic,
    ));

    // Score bar fill
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _barFill = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _barController, curve: Curves.easeOutCubic),
    );

    // Slide up content
    _slideUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideUp = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideUpController, curve: Curves.easeOut),
    );

    // Sequence animations
    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _slideUpController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _barController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _xpCountController.forward();
    // Show achievement popup for wins
    if (widget.won) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() => _showAchievement = true);
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _headerController.dispose();
    _xpCountController.dispose();
    _barController.dispose();
    _slideUpController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: Stack(
          children: [
            // Confetti layer (victory only)
            if (widget.won)
              AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ConfettiPainter(
                      progress: _confettiController.value,
                      colors: const [
                        AppTheme.accentCyan,
                        AppTheme.accentPurple,
                        AppTheme.accentMagenta,
                        AppTheme.accentGold,
                        AppTheme.accentGreen,
                        AppTheme.accentOrange,
                      ],
                    ),
                  );
                },
              ),

            // Main content
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildHeader(),
                    const SizedBox(height: 36),
                    _buildSummaryCard(),
                    const SizedBox(height: 20),
                    _buildEloChange(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Achievement popup overlay
            if (_showAchievement) _buildAchievementPopup(),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return ScaleTransition(
      scale: _headerScale,
      child: Column(
        children: [
          // Victory / Defeat glow icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.won
                  ? AppTheme.accentGold.withAlpha(20)
                  : AppTheme.accentMagenta.withAlpha(20),
              boxShadow: AppTheme.neonGlow(
                widget.won ? AppTheme.accentGold : AppTheme.accentMagenta,
                blur: 30,
              ),
            ),
            child: Icon(
              widget.won
                  ? Icons.emoji_events_rounded
                  : Icons.sentiment_dissatisfied_rounded,
              color: widget.won ? AppTheme.accentGold : AppTheme.accentMagenta,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: widget.won
                  ? [AppTheme.accentGold, AppTheme.accentOrange]
                  : [AppTheme.accentMagenta, AppTheme.accentPurple],
            ).createShader(bounds),
            child: Text(
              widget.won ? 'VICTORY' : 'DEFEAT',
              style: AppTheme.headerStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.won
                ? 'Outstanding performance!'
                : 'Better luck next time.',
            style: AppTheme.bodyStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Summary Card ──────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return AnimatedBuilder(
      animation: _slideUp,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 40 * _slideUp.value),
          child: Opacity(
            opacity: (1 - _slideUp.value).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GlassMorphism.glow(
        glowColor: widget.won ? AppTheme.accentGold : AppTheme.accentMagenta,
        glowBlurRadius: 16,
        borderColor: widget.won
            ? AppTheme.accentGold.withAlpha(60)
            : AppTheme.accentMagenta.withAlpha(60),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Score comparison
            Text(
              'SCORE',
              style: AppTheme.headerStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            _buildScoreBar(),
            const SizedBox(height: 24),
            // Time comparison
            Text(
              'TIME TAKEN',
              style: AppTheme.headerStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimeComparison(),
            const SizedBox(height: 24),
            // XP earned
            _buildXpDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar() {
    final total = widget.playerScore + widget.opponentScore;
    final playerRatio = total > 0 ? widget.playerScore / total : 0.5;

    return AnimatedBuilder(
      animation: _barFill,
      builder: (context, _) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(widget.playerScore * _barFill.value).round()}',
                  style: AppTheme.headerStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentCyan,
                  ),
                ),
                Text(
                  '${(widget.opponentScore * _barFill.value).round()}',
                  style: AppTheme.headerStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentMagenta,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('You', style: AppTheme.bodyStyle(fontSize: 11, color: AppTheme.textTertiary)),
                Text('Opponent', style: AppTheme.bodyStyle(fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
            const SizedBox(height: 8),
            // Dual-color progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (playerRatio * 100 * _barFill.value).round().clamp(1, 99),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: ((1 - playerRatio) * 100 * _barFill.value)
                          .round()
                          .clamp(1, 99),
                      child: Container(color: AppTheme.accentMagenta.withAlpha(180)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeComparison() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Icon(Icons.timer_rounded, color: AppTheme.accentCyan, size: 20),
              const SizedBox(height: 4),
              Text(
                _formatTime(widget.playerTime),
                style: AppTheme.headerStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentCyan,
                ),
              ),
              Text('You',
                  style: AppTheme.bodyStyle(
                      fontSize: 10, color: AppTheme.textTertiary)),
            ],
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: AppTheme.glassBorder,
        ),
        Expanded(
          child: Column(
            children: [
              Icon(Icons.timer_rounded,
                  color: AppTheme.accentMagenta, size: 20),
              const SizedBox(height: 4),
              Text(
                _formatTime(widget.opponentTime),
                style: AppTheme.headerStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentMagenta,
                ),
              ),
              Text('Opponent',
                  style: AppTheme.bodyStyle(
                      fontSize: 10, color: AppTheme.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildXpDisplay() {
    return AnimatedBuilder(
      animation: _xpCount,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.accentGold.withAlpha(15),
            border: Border.all(color: AppTheme.accentGold.withAlpha(40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.accentGold, size: 22),
              const SizedBox(width: 10),
              Text(
                '+${_xpCount.value.round()} XP',
                style: AppTheme.headerStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentGold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── ELO Change ────────────────────────────────────────────────────

  Widget _buildEloChange() {
    final isPositive = widget.eloChange >= 0;
    final color = isPositive ? AppTheme.accentGreen : AppTheme.accentMagenta;

    return GlassMorphism(
      borderRadius: 12,
      borderColor: color.withAlpha(50),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'ELO: ${isPositive ? "+" : ""}${widget.eloChange}',
            style: AppTheme.headerStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Action Buttons ────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Rematch
        Expanded(
          child: GestureDetector(
            onTap: () {
              // Re-enter matchmaking
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    widget.modeColor,
                    widget.modeColor.withAlpha(180),
                  ],
                ),
                boxShadow: AppTheme.neonGlow(widget.modeColor, blur: 10),
              ),
              child: Center(
                child: Text(
                  'REMATCH',
                  style: AppTheme.headerStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Back to Arena
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const BattleLobbyScreen()),
                (route) => route.isFirst,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.glassBorder),
                color: AppTheme.glassFill,
              ),
              child: Center(
                child: Text(
                  'BACK TO ARENA',
                  style: AppTheme.headerStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Achievement Popup ─────────────────────────────────────────────

  Widget _buildAchievementPopup() {
    return AnimatedOpacity(
      opacity: _showAchievement ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100, left: 24, right: 24),
          child: GlassMorphism.glow(
            glowColor: AppTheme.accentGold,
            glowBlurRadius: 20,
            borderColor: AppTheme.accentGold.withAlpha(100),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentGold.withAlpha(30),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: AppTheme.accentGold,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACHIEVEMENT UNLOCKED',
                        style: AppTheme.bodyStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentGold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'First Blood - Win your first battle!',
                        style: AppTheme.bodyStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppTheme.textTertiary,
                  onPressed: () => setState(() => _showAchievement = false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Confetti Custom Painter ─────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final Random _rng = Random(42); // Fixed seed for consistent shapes

  _ConfettiPainter({required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    const particleCount = 60;

    for (int i = 0; i < particleCount; i++) {
      final seed = _rng.nextDouble();
      final colorIndex = i % colors.length;
      final color = colors[colorIndex];

      // Each particle has its own phase based on seed
      final phase = (progress + seed) % 1.0;
      final x = _rng.nextDouble() * size.width;
      final startY = -20.0;
      final endY = size.height + 20;
      final y = startY + (endY - startY) * phase;

      // Horizontal drift
      final drift = sin(phase * pi * 3 + seed * pi * 2) * 30;

      final opacity = phase < 0.8 ? 1.0 : (1.0 - phase) / 0.2;
      final paint = Paint()
        ..color = color.withAlpha((opacity * 200).round());

      // Alternate between rectangles and circles
      if (i % 3 == 0) {
        // Small rectangle (confetti strip)
        final rotation = phase * pi * 4 + seed * pi;
        canvas.save();
        canvas.translate(x + drift, y);
        canvas.rotate(rotation);
        canvas.drawRect(
          const Rect.fromLTWH(-6, -2, 12, 4),
          paint,
        );
        canvas.restore();
      } else if (i % 3 == 1) {
        // Circle
        canvas.drawCircle(
          Offset(x + drift, y),
          3 + seed * 2,
          paint,
        );
      } else {
        // Diamond
        final path = Path()
          ..moveTo(x + drift, y - 4)
          ..lineTo(x + drift + 3, y)
          ..lineTo(x + drift, y + 4)
          ..lineTo(x + drift - 3, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
