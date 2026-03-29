import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/features/battle/screens/battle_result_screen.dart';
import 'package:vidyasetu/features/battle/widgets/battle_timer_widget.dart';

import '../data/battle_question.dart';
import '../services/battle_service.dart';
import '../services/bot_service.dart';
import '../widgets/race_animation.dart';
import '../widgets/trap_animation.dart';
import '../widgets/duel_animation.dart';

/// The live battle screen with multi-question flow, bot opponent,
/// mode-specific animations, and real-time score tracking.
class BattleScreen extends StatefulWidget {
  final String battleId;
  final String mode;
  final Color modeColor;
  final bool isBot;
  final String opponentName;

  const BattleScreen({
    super.key,
    required this.battleId,
    required this.mode,
    required this.modeColor,
    this.isBot = true,
    this.opponentName = 'Bot',
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with TickerProviderStateMixin {
  // ── Questions ─────────────────────────────────────────
  List<BattleQuestion> _questions = [];
  bool _loadingQuestions = true;
  int _currentIndex = 0;
  int? _selectedChoice;
  bool _answered = false;
  bool _gameOver = false;

  // ── Scores ────────────────────────────────────────────
  int _playerScore = 0;
  int _opponentScore = 0;

  // ── Timer ─────────────────────────────────────────────
  int _timeRemaining = 180; // varies by mode
  int get _totalTime {
    switch (widget.mode) {
      case 'speed_solve': return 180; // 3 min
      case 'mind_trap': return 300; // 5 min
      case 'scenario_battle': return 420; // 7 min
      default: return 180;
    }
  }

  // ── Bot ────────────────────────────────────────────────
  Function()? _cancelBot;

  // ── Multiplayer ───────────────────────────────────────
  final _battleService = BattleService();
  StreamSubscription? _battleSub;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Animation ─────────────────────────────────────────
  late AnimationController _correctFlashCtrl;
  late AnimationController _wrongShakeCtrl;

  @override
  void initState() {
    super.initState();
    _timeRemaining = _totalTime;

    // Animation controllers
    _correctFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wrongShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (widget.isBot) {
      // Bot mode: load questions locally
      _questions = BotService.instance.getQuestions(widget.mode, count: 7);
      _loadingQuestions = false;
      _cancelBot = BotService.instance.simulateBot(
        mode: widget.mode,
        totalQuestions: _questions.length,
        onBotAnswer: _onBotAnswer,
      );
    } else {
      // Multiplayer: load questions from Firestore and listen for opponent
      _initMultiplayer();
    }
  }

  Future<void> _initMultiplayer() async {
    // Listen to the battle document for real-time score sync
    _battleSub = _battleService.battleStream(widget.battleId).listen((data) {
      if (data == null || !mounted || _gameOver) return;

      final isPlayer1 = data['player1Id'] == _uid;
      final oppScoreField = isPlayer1 ? 'player2Score' : 'player1Score';
      final oppScore = (data[oppScoreField] as num?)?.toInt() ?? 0;
      final oppAnswered = isPlayer1
          ? (data['player2Answered'] as num?)?.toInt() ?? 0
          : (data['player1Answered'] as num?)?.toInt() ?? 0;
      final totalRounds = (data['totalRounds'] as num?)?.toInt() ?? 7;

      if (!mounted) return;
      setState(() => _opponentScore = oppScore);

      // If opponent finished all questions and we're done too, end the game
      if (oppAnswered >= totalRounds && _currentIndex >= _questions.length - 1 && _answered) {
        _endGame();
      }

      // Load questions from battle doc on first snapshot
      if (_loadingQuestions) {
        final questionsData = data['questions'] as List<dynamic>? ?? [];
        if (questionsData.isNotEmpty) {
          _questions = questionsData.map((q) {
            final m = q as Map<String, dynamic>;
            return BattleQuestion(
              question: m['question'] as String? ?? '',
              options: List<String>.from(m['options'] ?? []),
              correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
              explanation: m['explanation'] as String?,
              difficulty: m['difficulty'] as String? ?? 'medium',
              category: m['category'] as String? ?? 'general',
            );
          }).toList();
          if (mounted) setState(() => _loadingQuestions = false);
        }
      }

      // Check if battle was completed by the other player ending it
      final status = data['status'] as String? ?? '';
      if (status == 'completed' && !_gameOver) {
        _endGame();
      }
    });
  }

  @override
  void dispose() {
    _cancelBot?.call();
    _battleSub?.cancel();
    _correctFlashCtrl.dispose();
    _wrongShakeCtrl.dispose();
    super.dispose();
  }

  // ── Progress (0.0 to 1.0) for animations ──────────────
  double get _playerProgress =>
      _questions.isEmpty ? 0 : _playerScore / _questions.length;
  double get _opponentProgress =>
      _questions.isEmpty ? 0 : _opponentScore / _questions.length;

  BattleQuestion? get _currentQuestion =>
      _questions.isNotEmpty && _currentIndex < _questions.length
          ? _questions[_currentIndex]
          : null;

  // ── Bot Answer Callback ───────────────────────────────
  void _onBotAnswer(bool isCorrect) {
    if (!mounted || _gameOver) return;
    setState(() {
      if (isCorrect) _opponentScore++;
    });
    // Check if bot finished all questions
    if (_opponentScore >= _questions.length) {
      _endGame();
    }
  }

  // ── Player Answer ─────────────────────────────────────
  void _onSelectChoice(int index) {
    if (_answered || _gameOver) return;
    setState(() => _selectedChoice = index);
  }

  void _submitAnswer() {
    if (_selectedChoice == null || _answered || _gameOver || _currentQuestion == null) return;

    final correct = _selectedChoice == _currentQuestion!.correctIndex;
    setState(() {
      _answered = true;
      if (correct) _playerScore++;
    });

    // Submit to Firestore for multiplayer
    if (!widget.isBot) {
      _battleService.submitAnswer(
        battleId: widget.battleId,
        questionIndex: _currentIndex,
        selectedOption: _selectedChoice!,
        isCorrect: correct,
      );
    }

    // Play animation
    if (correct) {
      _correctFlashCtrl.forward(from: 0);
    } else {
      _wrongShakeCtrl.forward(from: 0);
    }

    // Advance after brief delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedChoice = null;
          _answered = false;
        });
      } else {
        _endGame();
      }
    });
  }

  // ── Timer Tick ────────────────────────────────────────
  void _onTimerTick(int remaining) {
    if (!mounted) return;
    setState(() => _timeRemaining = remaining);
    if (remaining <= 0 && !_gameOver) {
      _endGame();
    }
  }

  // ── End Game ──────────────────────────────────────────
  void _endGame() {
    if (_gameOver) return;
    _gameOver = true;
    _cancelBot?.call();
    _battleSub?.cancel();

    // End battle in Firestore for multiplayer
    if (!widget.isBot && widget.battleId.isNotEmpty) {
      _battleService.endBattle(widget.battleId);
    }

    final timeTaken = _totalTime - _timeRemaining;
    final won = _playerScore > _opponentScore;
    final tied = _playerScore == _opponentScore;
    final xp = won ? 50 + (_playerScore * 10) : 10 + (_playerScore * 5);
    final elo = won ? 20 + _playerScore * 3 : (tied ? 0 : -(10 + _opponentScore * 2));

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BattleResultScreen(
          battleId: widget.battleId,
          playerScore: _playerScore,
          opponentScore: _opponentScore,
          playerTime: timeTaken,
          opponentTime: timeTaken + 10 + (_opponentScore * 5), // estimated
          won: won,
          xpEarned: xp,
          eloChange: elo,
          modeColor: widget.modeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingQuestions || _currentQuestion == null) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.scaffoldDecoration,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: widget.modeColor),
                const SizedBox(height: 16),
                Text(
                  'Loading battle...',
                  style: AppTheme.bodyStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              // Mode-specific animation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildModeAnimation(),
              ),
              // Question counter
              _buildQuestionCounter(),
              // Challenge area
              Expanded(
                child: _buildChallengeArea(),
              ),
              // Answer options
              _buildAnswerOptions(),
              // Submit button
              _buildSubmitButton(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top Bar ───────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // Player score
          GlassMorphism(
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderColor: widget.modeColor.withAlpha(80),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: AppTheme.accentGold, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_playerScore',
                  style: AppTheme.headerStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentGold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Timer
          BattleTimerWidget(
            totalSeconds: _totalTime,
            onTick: _onTimerTick,
            size: 56,
            strokeWidth: 3.5,
          ),
          const Spacer(),
          // Opponent score
          GlassMorphism(
            borderRadius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            borderColor: AppTheme.accentMagenta.withAlpha(80),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_opponentScore',
                  style: AppTheme.headerStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentMagenta,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.star_rounded, color: AppTheme.accentMagenta, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mode Animation ────────────────────────────────────────────

  Widget _buildModeAnimation() {
    switch (widget.mode) {
      case 'speed_solve':
        return RaceAnimation(
          playerProgress: _playerProgress,
          opponentProgress: _opponentProgress,
          playerColor: widget.modeColor,
          opponentColor: AppTheme.accentMagenta,
        );
      case 'mind_trap':
        return TrapAnimation(
          playerProgress: _playerProgress,
          opponentProgress: _opponentProgress,
          playerColor: widget.modeColor,
          opponentColor: AppTheme.accentMagenta,
        );
      case 'scenario_battle':
        return DuelAnimation(
          playerProgress: _playerProgress,
          opponentProgress: _opponentProgress,
          playerColor: widget.modeColor,
          opponentColor: AppTheme.accentMagenta,
        );
      default:
        return RaceAnimation(
          playerProgress: _playerProgress,
          opponentProgress: _opponentProgress,
          playerColor: widget.modeColor,
          opponentColor: AppTheme.accentMagenta,
        );
    }
  }

  // ─── Question Counter ──────────────────────────────────────────

  Widget _buildQuestionCounter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Question dots
          for (int i = 0; i < _questions.length; i++) ...[
            Container(
              width: i == _currentIndex ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i < _currentIndex
                    ? AppTheme.accentGreen.withAlpha(180)
                    : i == _currentIndex
                        ? widget.modeColor
                        : AppTheme.surfaceLight,
              ),
            ),
            if (i < _questions.length - 1) const SizedBox(width: 4),
          ],
          const Spacer(),
          // Question number
          Text(
            '${_currentIndex + 1}/${_questions.length}',
            style: AppTheme.bodyStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          // Opponent status
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.accentGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppTheme.accentGreen.withAlpha(100), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            widget.opponentName,
            style: AppTheme.bodyStyle(
              fontSize: 10,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Challenge Area ────────────────────────────────────────────

  Widget _buildChallengeArea() {
    final q = _currentQuestion!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassMorphism(
        borderRadius: 16,
        borderColor: widget.modeColor.withAlpha(50),
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category + difficulty
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.modeColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: widget.modeColor.withAlpha(60)),
                    ),
                    child: Text(
                      q.category.toUpperCase(),
                      style: AppTheme.bodyStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: widget.modeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _difficultyColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _difficultyColor.withAlpha(50)),
                    ),
                    child: Text(
                      q.difficulty.toUpperCase(),
                      style: AppTheme.bodyStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _difficultyColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Question text
              Text(
                q.question,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _difficultyColor {
    final q = _currentQuestion;
    if (q == null) return AppTheme.accentCyan;
    switch (q.difficulty) {
      case 'easy': return AppTheme.accentGreen;
      case 'medium': return AppTheme.accentGold;
      case 'hard': return AppTheme.accentMagenta;
      default: return AppTheme.accentCyan;
    }
  }

  // ─── Answer Options ────────────────────────────────────────────

  Widget _buildAnswerOptions() {
    final q = _currentQuestion!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(q.options.length, (index) {
          final isSelected = _selectedChoice == index;
          final isCorrect = index == q.correctIndex;

          Color borderColor = AppTheme.glassBorder;
          double borderWidth = 0.8;
          Color? bgTint;

          if (_answered) {
            if (isCorrect) {
              borderColor = AppTheme.accentGreen;
              borderWidth = 1.5;
              bgTint = AppTheme.accentGreen.withAlpha(15);
            } else if (isSelected && !isCorrect) {
              borderColor = AppTheme.accentMagenta;
              borderWidth = 1.5;
              bgTint = AppTheme.accentMagenta.withAlpha(10);
            }
          } else if (isSelected) {
            borderColor = widget.modeColor;
            borderWidth = 1.5;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _onSelectChoice(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: GlassMorphism(
                  borderRadius: 12,
                  borderColor: borderColor,
                  borderWidth: borderWidth,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  gradientColors: bgTint != null
                      ? [bgTint, bgTint.withAlpha(5)]
                      : null,
                  child: Row(
                    children: [
                      // Option letter
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected && !_answered
                              ? widget.modeColor.withAlpha(25)
                              : Colors.transparent,
                          border: Border.all(
                            color: _answered && isCorrect
                                ? AppTheme.accentGreen
                                : isSelected
                                    ? widget.modeColor
                                    : AppTheme.textTertiary,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: _answered && isCorrect
                              ? Icon(Icons.check, size: 14, color: AppTheme.accentGreen)
                              : _answered && isSelected && !isCorrect
                                  ? Icon(Icons.close, size: 14, color: AppTheme.accentMagenta)
                                  : Text(
                                      String.fromCharCode(65 + index),
                                      style: AppTheme.bodyStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? widget.modeColor
                                            : AppTheme.textTertiary,
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          q.options[index],
                          style: AppTheme.bodyStyle(
                            fontSize: 13,
                            color: _answered && isCorrect
                                ? AppTheme.accentGreen
                                : isSelected
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                            fontWeight: isSelected || (_answered && isCorrect)
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Submit Button ─────────────────────────────────────────────

  Widget _buildSubmitButton() {
    final canSubmit = _selectedChoice != null && !_answered && !_gameOver;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: canSubmit ? _submitAnswer : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: canSubmit
                ? LinearGradient(
                    colors: [widget.modeColor, widget.modeColor.withAlpha(180)],
                  )
                : const LinearGradient(
                    colors: [AppTheme.surfaceLight, AppTheme.surfaceDark],
                  ),
            boxShadow: canSubmit
                ? AppTheme.neonGlow(widget.modeColor, blur: 10)
                : null,
          ),
          child: Center(
            child: Text(
              _answered ? 'NEXT...' : 'SUBMIT ANSWER',
              style: AppTheme.headerStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: canSubmit ? Colors.black : AppTheme.textTertiary,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
