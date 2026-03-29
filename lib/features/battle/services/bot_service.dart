import 'dart:async';
import 'dart:math';

import '../data/battle_question.dart';
import '../data/speed_solve_questions.dart';
import '../data/mind_trap_questions.dart';
import '../data/scenario_questions.dart';

/// Simulates an AI bot opponent for battle mode.
class BotService {
  BotService._();
  static final instance = BotService._();

  final _rng = Random();

  // ── Bot Profiles ──────────────────────────────────────────────

  static const _botNames = [
    'QuizBot Alpha', 'NeoMind', 'CodeNinja', 'ByteWizard',
    'AlgoKing', 'LogicLord', 'BrainStorm', 'ThinkTank',
    'DataDragon', 'SynapseX', 'MindMeld', 'Eureka',
    'CipherBot', 'QuantumQ', 'SparkAI', 'TurboSolve',
  ];

  static const _botLeagues = ['Silver', 'Gold', 'Platinum', 'Diamond'];

  String get randomBotName => _botNames[_rng.nextInt(_botNames.length)];
  String get randomBotLeague => _botLeagues[_rng.nextInt(_botLeagues.length)];
  String get randomWinRate => '${50 + _rng.nextInt(30)}%';
  int get randomRating => 1200 + _rng.nextInt(600);

  // ── Question Selection ────────────────────────────────────────

  /// Returns a shuffled list of [count] questions for the given [mode].
  List<BattleQuestion> getQuestions(String mode, {int count = 7}) {
    final List<BattleQuestion> pool;
    switch (mode) {
      case 'speed_solve':
        pool = List.of(SpeedSolveQuestions.all);
        break;
      case 'mind_trap':
        pool = List.of(MindTrapQuestions.all);
        break;
      case 'scenario_battle':
        pool = List.of(ScenarioQuestions.all);
        break;
      default:
        pool = List.of(SpeedSolveQuestions.all);
    }
    pool.shuffle(_rng);
    return pool.take(count).toList();
  }

  // ── Bot Answer Simulation ─────────────────────────────────────

  /// Starts simulating a bot answering [totalQuestions] questions.
  /// Calls [onBotAnswer] with (isCorrect) each time the bot "answers".
  /// Returns a cancel function.
  Function() simulateBot({
    required String mode,
    required int totalQuestions,
    required void Function(bool isCorrect) onBotAnswer,
  }) {
    final timers = <Timer>[];
    var answeredCount = 0;

    // Bot accuracy & speed by mode
    final double accuracy;
    final int minDelayMs;
    final int maxDelayMs;

    switch (mode) {
      case 'speed_solve':
        accuracy = 0.6 + _rng.nextDouble() * 0.2; // 60-80%
        minDelayMs = 4000;
        maxDelayMs = 10000;
        break;
      case 'mind_trap':
        accuracy = 0.5 + _rng.nextDouble() * 0.25; // 50-75%
        minDelayMs = 5000;
        maxDelayMs = 14000;
        break;
      case 'scenario_battle':
        accuracy = 0.55 + _rng.nextDouble() * 0.25; // 55-80%
        minDelayMs = 5000;
        maxDelayMs = 12000;
        break;
      default:
        accuracy = 0.6;
        minDelayMs = 5000;
        maxDelayMs = 10000;
    }

    void scheduleNext() {
      if (answeredCount >= totalQuestions) return;

      final delay = Duration(
        milliseconds: minDelayMs + _rng.nextInt(maxDelayMs - minDelayMs),
      );

      final timer = Timer(delay, () {
        if (answeredCount >= totalQuestions) return;
        answeredCount++;
        final correct = _rng.nextDouble() < accuracy;
        onBotAnswer(correct);
        scheduleNext();
      });
      timers.add(timer);
    }

    // Start first bot answer after initial delay
    final startDelay = Timer(
      Duration(milliseconds: 2000 + _rng.nextInt(3000)),
      scheduleNext,
    );
    timers.add(startDelay);

    // Return cancel function
    return () {
      for (final t in timers) {
        t.cancel();
      }
    };
  }
}
