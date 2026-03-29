import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/knowledge_graph/data/prerequisite_graph.dart';

/// Client-side deterministic daily challenge.
/// Challenge is derived from the date so every user sees the same one.
class DailyChallengeService {
  DailyChallengeService._();
  static final instance = DailyChallengeService._();

  DailyChallenge? _cached;

  /// Get today's challenge. Deterministic based on date.
  DailyChallenge getTodayChallenge() {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (_cached != null && _cached!.dateKey == dateKey) return _cached!;

    final concepts = PrerequisiteGraph.concepts;
    final index = dateKey.hashCode.abs() % concepts.length;
    final concept = concepts[index];

    // Difficulty by day of week (Mon=1 easy ... Sun=7 hard)
    final dow = today.weekday;
    final difficulty = dow <= 2
        ? 'Easy'
        : dow <= 4
            ? 'Medium'
            : dow <= 6
                ? 'Hard'
                : 'Expert';

    final xpReward = switch (difficulty) {
      'Easy' => 25,
      'Medium' => 40,
      'Hard' => 60,
      'Expert' => 100,
      _ => 30,
    };

    _cached = DailyChallenge(
      dateKey: dateKey,
      conceptId: concept.id,
      topicName: concept.name,
      subject: concept.subject,
      description: concept.description,
      difficulty: difficulty,
      xpReward: xpReward,
    );

    return _cached!;
  }

  /// Check if today's challenge is already completed.
  Future<bool> isCompleted() async {
    final challenge = getTodayChallenge();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('daily_${challenge.dateKey}') ?? false;
  }

  /// Mark today's challenge as completed.
  Future<void> markCompleted() async {
    final challenge = getTodayChallenge();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_${challenge.dateKey}', true);

    // Award XP in Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'xp': FieldValue.increment(challenge.xpReward),
        });
      }
    } catch (_) {}
  }
}

class DailyChallenge {
  final String dateKey;
  final String conceptId;
  final String topicName;
  final String subject;
  final String description;
  final String difficulty;
  final int xpReward;

  const DailyChallenge({
    required this.dateKey,
    required this.conceptId,
    required this.topicName,
    required this.subject,
    required this.description,
    required this.difficulty,
    required this.xpReward,
  });
}
