import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/features/battle/screens/battle_screen.dart';
import 'package:vidyasetu/features/battle/services/battle_service.dart';
import 'package:vidyasetu/features/battle/services/bot_service.dart';

/// Animated matchmaking screen with real Firestore matchmaking.
/// Falls back to bot opponent if no real player joins within 12 seconds.
class BattleMatchmakingScreen extends StatefulWidget {
  final String mode;
  final String modeName;
  final Color modeColor;

  const BattleMatchmakingScreen({
    super.key,
    required this.mode,
    required this.modeName,
    required this.modeColor,
  });

  @override
  State<BattleMatchmakingScreen> createState() =>
      _BattleMatchmakingScreenState();
}

class _BattleMatchmakingScreenState extends State<BattleMatchmakingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _pulseRingController;
  late final AnimationController _opponentSlideController;
  late final AnimationController _shimmerController;

  late final Animation<double> _scanRotation;
  late final Animation<double> _pulseRing;
  late final Animation<Offset> _opponentSlide;
  late final Animation<double> _shimmer;

  bool _opponentFound = false;
  bool _isBot = false;
  int _countdown = 3;
  String _battleId = '';

  // Player data
  final _playerName = 'You';
  final _playerLeague = 'Gold';
  final _playerWinRate = '72%';
  final _playerRating = 1450;

  String _opponentName = '';
  String _opponentLeague = '';
  String _opponentWinRate = '';
  int _opponentRating = 0;

  final _battleService = BattleService();
  StreamSubscription? _battleSub;
  Timer? _botFallbackTimer;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _scanRotation = Tween<double>(begin: 0, end: 2 * pi).animate(_scanController);

    _pulseRingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulseRing = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseRingController, curve: Curves.easeOut),
    );

    _opponentSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opponentSlide = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _opponentSlideController,
      curve: Curves.easeOutBack,
    ));

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(_shimmerController);

    _startMatchmaking();
  }

  Future<void> _startMatchmaking() async {
    // Start bot fallback timer IMMEDIATELY — if Firestore hangs, we still get a game
    _botFallbackTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _cancelled || _opponentFound) return;
      _battleSub?.cancel();
      _fallbackToBot();
    });

    try {
      // Create or join a real Firestore battle
      _battleId = await _battleService.createOrJoinMatch(mode: widget.mode);

      if (!mounted || _cancelled) return;

      // Listen to the battle doc for opponent joining
      _battleSub = _battleService.battleStream(_battleId).listen((data) {
        if (data == null || !mounted || _cancelled) return;

        final status = data['status'] as String? ?? 'waiting';
        final p2 = data['player2Id'] as String? ?? '';
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

        if (status == 'in_progress' && p2.isNotEmpty) {
          // Real opponent found!
          _battleSub?.cancel();
          _botFallbackTimer?.cancel();

          // Determine opponent display name
          final isPlayer1 = data['player1Id'] == uid;
          _onOpponentFound(
            name: isPlayer1 ? 'Opponent' : 'Host',
            league: 'Gold',
            winRate: '65%',
            rating: 1400,
            isBot: false,
          );
        }
      });
    } catch (e) {
      // If Firestore fails, go straight to bot
      if (!mounted || _cancelled) return;
      _botFallbackTimer?.cancel();
      _fallbackToBot();
    }
  }

  void _fallbackToBot() {
    final bot = BotService.instance;
    _isBot = true;
    _onOpponentFound(
      name: bot.randomBotName,
      league: bot.randomBotLeague,
      winRate: bot.randomWinRate,
      rating: bot.randomRating,
      isBot: true,
    );
  }

  void _onOpponentFound({
    required String name,
    required String league,
    required String winRate,
    required int rating,
    required bool isBot,
  }) {
    if (!mounted || _opponentFound) return;

    setState(() {
      _opponentFound = true;
      _isBot = isBot;
      _opponentName = name;
      _opponentLeague = league;
      _opponentWinRate = winRate;
      _opponentRating = rating;
    });

    _scanController.stop();
    _pulseRingController.stop();
    _shimmerController.stop();
    _opponentSlideController.forward();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _startCountdown();
    });
  }

  void _startCountdown() async {
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          battleId: _battleId.isNotEmpty ? _battleId : 'demo_battle',
          mode: widget.mode,
          modeColor: widget.modeColor,
          isBot: _isBot,
          opponentName: _opponentName,
        ),
      ),
    );
  }

  void _onCancel() {
    _cancelled = true;
    _battleSub?.cancel();
    _botFallbackTimer?.cancel();
    // Clean up Firestore battle if we created it
    if (_battleId.isNotEmpty) {
      _battleService.cancelMatch(_battleId);
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _battleSub?.cancel();
    _botFallbackTimer?.cancel();
    _scanController.dispose();
    _pulseRingController.dispose();
    _opponentSlideController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                widget.modeName.toUpperCase(),
                style: AppTheme.headerStyle(
                  fontSize: 14,
                  color: widget.modeColor,
                  letterSpacing: 4,
                ),
              ),
              const Spacer(),
              _buildMatchmakingVisual(),
              const Spacer(),
              _buildStatusText(),
              const SizedBox(height: 40),
              if (!_opponentFound)
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: OutlinedButton.icon(
                    onPressed: _onCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('CANCEL'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentMagenta,
                      side: const BorderSide(color: AppTheme.accentMagenta),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    ),
                  ),
                ),
              if (_opponentFound) const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchmakingVisual() {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!_opponentFound) _buildPulsingRings(),
          Positioned(
            left: 20,
            child: _buildPlayerCard(
              name: _playerName,
              league: _playerLeague,
              winRate: _playerWinRate,
              rating: _playerRating,
              color: widget.modeColor,
              isPlayer: true,
            ),
          ),
          _buildVsIndicator(),
          Positioned(
            right: 20,
            child: _opponentFound
                ? SlideTransition(
                    position: _opponentSlide,
                    child: _buildPlayerCard(
                      name: _opponentName,
                      league: _opponentLeague,
                      winRate: _opponentWinRate,
                      rating: _opponentRating,
                      color: AppTheme.accentMagenta,
                      isPlayer: false,
                    ),
                  )
                : AnimatedBuilder(
                    animation: _scanRotation,
                    builder: (context, _) {
                      return Container(
                        width: 130,
                        height: 170,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.glassBorder.withAlpha(60),
                          ),
                          color: AppTheme.glassFill,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                widget.modeColor.withAlpha(150),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingRings() {
    return AnimatedBuilder(
      animation: _pulseRing,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: _PulseRingPainter(
            progress: _pulseRing.value,
            color: widget.modeColor,
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required String league,
    required String winRate,
    required int rating,
    required Color color,
    required bool isPlayer,
  }) {
    return GlassMorphism(
      borderRadius: 16,
      borderColor: color.withAlpha(80),
      padding: const EdgeInsets.all(14),
      width: 130,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              gradient: RadialGradient(
                colors: [color.withAlpha(40), color.withAlpha(10)],
              ),
            ),
            child: Icon(
              isPlayer ? Icons.person_rounded : Icons.psychology_alt_rounded,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: AppTheme.headerStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            league,
            style: AppTheme.bodyStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(winRate, style: AppTheme.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('Win%', style: AppTheme.bodyStyle(fontSize: 9, color: AppTheme.textTertiary)),
                ],
              ),
              Column(
                children: [
                  Text('$rating', style: AppTheme.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('ELO', style: AppTheme.bodyStyle(fontSize: 9, color: AppTheme.textTertiary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVsIndicator() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _opponentFound && _countdown > 0
          ? Text(
              '$_countdown',
              key: ValueKey(_countdown),
              style: AppTheme.headerStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: widget.modeColor,
                letterSpacing: 0,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [AppTheme.accentOrange, AppTheme.accentMagenta],
                  ).createShader(bounds),
                  child: Text(
                    'VS',
                    style: AppTheme.headerStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [Colors.transparent, AppTheme.accentOrange, Colors.transparent],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusText() {
    if (_opponentFound && _countdown > 0) {
      return Column(
        children: [
          Text(
            'Battle begins in...',
            style: AppTheme.bodyStyle(fontSize: 16, fontWeight: FontWeight.w600, color: widget.modeColor),
          ),
          if (_isBot)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'vs AI Bot',
                style: AppTheme.bodyStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Real opponent found!',
                style: AppTheme.bodyStyle(fontSize: 11, color: AppTheme.accentGreen),
              ),
            ),
        ],
      );
    }
    if (_opponentFound) {
      return Text(
        'GET READY!',
        style: AppTheme.headerStyle(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: widget.modeColor, letterSpacing: 3,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [AppTheme.textTertiary, widget.modeColor, AppTheme.textTertiary],
              stops: [
                (_shimmer.value - 0.3).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(
            'Searching for opponent...',
            style: AppTheme.bodyStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulseRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.3;

      final paint = Paint()
        ..color = color.withAlpha((opacity * 255).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
