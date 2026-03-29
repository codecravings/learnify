import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client-side achievement checking and awarding.
/// No Cloud Functions needed — runs entirely on device.
class AchievementService {
  AchievementService._();
  static final instance = AchievementService._();

  static const _prefsKey = 'unlocked_achievements';

  /// All achievement definitions.
  static final List<Achievement> definitions = [
    // ── Study ──
    const Achievement(
      id: 'first_lesson',
      name: 'First Step',
      description: 'Complete your first lesson',
      category: 'study',
      rarity: 'common',
      xpReward: 25,
      icon: 'school',
    ),
    const Achievement(
      id: 'knowledge_seeker',
      name: 'Knowledge Seeker',
      description: 'Study 5 different topics',
      category: 'study',
      rarity: 'common',
      xpReward: 50,
      icon: 'explore',
    ),
    const Achievement(
      id: 'topic_master',
      name: 'Topic Master',
      description: 'Study 10 different topics',
      category: 'study',
      rarity: 'rare',
      xpReward: 100,
      icon: 'star',
    ),
    const Achievement(
      id: 'scholar_elite',
      name: 'Scholar Elite',
      description: 'Study 25 different topics',
      category: 'study',
      rarity: 'epic',
      xpReward: 250,
      icon: 'diamond',
    ),

    // ── Quiz ──
    const Achievement(
      id: 'first_quiz',
      name: 'Quiz Starter',
      description: 'Complete your first quiz',
      category: 'quiz',
      rarity: 'common',
      xpReward: 25,
      icon: 'quiz',
    ),
    const Achievement(
      id: 'perfect_score',
      name: 'Perfect Score',
      description: 'Score 100% on any quiz',
      category: 'quiz',
      rarity: 'rare',
      xpReward: 75,
      icon: 'military_tech',
    ),
    const Achievement(
      id: 'advanced_scholar',
      name: 'Advanced Scholar',
      description: 'Score 80%+ on 10 quizzes',
      category: 'quiz',
      rarity: 'epic',
      xpReward: 150,
      icon: 'psychology',
    ),
    const Achievement(
      id: 'quiz_legend',
      name: 'Quiz Legend',
      description: 'Complete 50 quizzes with 70%+ accuracy',
      category: 'quiz',
      rarity: 'legendary',
      xpReward: 300,
      icon: 'emoji_events',
    ),

    // ── Streak ──
    const Achievement(
      id: 'getting_started',
      name: 'Getting Started',
      description: '3-day study streak',
      category: 'streak',
      rarity: 'common',
      xpReward: 30,
      icon: 'local_fire_department',
    ),
    const Achievement(
      id: 'week_warrior',
      name: 'Week Warrior',
      description: '7-day study streak',
      category: 'streak',
      rarity: 'rare',
      xpReward: 75,
      icon: 'whatshot',
    ),
    const Achievement(
      id: 'fortnight_focus',
      name: 'Fortnight Focus',
      description: '14-day study streak',
      category: 'streak',
      rarity: 'epic',
      xpReward: 150,
      icon: 'bolt',
    ),
    const Achievement(
      id: 'monthly_master',
      name: 'Monthly Master',
      description: '30-day study streak',
      category: 'streak',
      rarity: 'legendary',
      xpReward: 500,
      icon: 'auto_awesome',
    ),

    // ── Special ──
    const Achievement(
      id: 'early_adopter',
      name: 'Early Adopter',
      description: 'Join Learnify',
      category: 'special',
      rarity: 'common',
      xpReward: 50,
      icon: 'rocket_launch',
    ),
    const Achievement(
      id: 'night_owl',
      name: 'Night Owl',
      description: 'Study after midnight',
      category: 'special',
      rarity: 'rare',
      xpReward: 40,
      icon: 'nightlight',
    ),
    const Achievement(
      id: 'xp_legend',
      name: 'XP Legend',
      description: 'Earn 5000 XP total',
      category: 'special',
      rarity: 'legendary',
      xpReward: 500,
      icon: 'diamond',
    ),
    const Achievement(
      id: 'multi_subject',
      name: 'Renaissance Mind',
      description: 'Study topics in 3+ subjects',
      category: 'special',
      rarity: 'rare',
      xpReward: 100,
      icon: 'hub',
    ),
  ];

  /// Check all achievements against current user data and award any newly unlocked ones.
  /// Returns list of newly unlocked achievements.
  Future<List<Achievement>> checkAndAward() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final alreadyUnlocked =
          Set<String>.from(prefs.getStringList(_prefsKey) ?? []);

      // Load user data from cache
      final cachedStr = prefs.getString('user_data_${user.uid}');
      if (cachedStr == null) return [];
      final userData =
          Map<String, dynamic>.from(jsonDecode(cachedStr) as Map);

      final xp = (userData['xp'] as num?)?.toInt() ?? 0;
      final streak = (userData['currentStreak'] as num?)?.toInt() ?? 0;
      final totalQuizzes =
          (userData['totalQuizzes'] as num?)?.toInt() ?? 0;
      final studiedTopics =
          (userData['studiedTopics'] as Map?)?.length ?? 0;

      // Count high-accuracy quizzes from studied topics
      int highAccuracyCount = 0;
      int perfectCount = 0;
      final subjects = <String>{};
      if (userData['studiedTopics'] is Map) {
        for (final entry
            in (userData['studiedTopics'] as Map).values) {
          if (entry is Map) {
            final acc = (entry['accuracy'] as num?)?.toInt() ?? 0;
            if (acc >= 70) highAccuracyCount++;
            if (acc == 100) perfectCount++;
            final name =
                (entry['name'] as String? ?? '').toLowerCase();
            if (name.contains('physics') ||
                name.contains('force') ||
                name.contains('energy') ||
                name.contains('wave') ||
                name.contains('motion')) {
              subjects.add('physics');
            } else if (name.contains('math') ||
                name.contains('algebra') ||
                name.contains('calculus') ||
                name.contains('geometry') ||
                name.contains('trigonometry')) {
              subjects.add('math');
            } else {
              subjects.add('other');
            }
          }
        }
      }

      final now = DateTime.now();
      final newlyUnlocked = <Achievement>[];

      for (final a in definitions) {
        if (alreadyUnlocked.contains(a.id)) continue;

        bool earned = false;
        switch (a.id) {
          case 'first_lesson':
            earned = totalQuizzes >= 1 || studiedTopics >= 1;
          case 'knowledge_seeker':
            earned = studiedTopics >= 5;
          case 'topic_master':
            earned = studiedTopics >= 10;
          case 'scholar_elite':
            earned = studiedTopics >= 25;
          case 'first_quiz':
            earned = totalQuizzes >= 1;
          case 'perfect_score':
            earned = perfectCount >= 1;
          case 'advanced_scholar':
            earned = highAccuracyCount >= 10;
          case 'quiz_legend':
            earned = highAccuracyCount >= 50;
          case 'getting_started':
            earned = streak >= 3;
          case 'week_warrior':
            earned = streak >= 7;
          case 'fortnight_focus':
            earned = streak >= 14;
          case 'monthly_master':
            earned = streak >= 30;
          case 'early_adopter':
            earned = true;
          case 'night_owl':
            earned = now.hour >= 0 && now.hour < 5;
          case 'xp_legend':
            earned = xp >= 5000;
          case 'multi_subject':
            earned = subjects.length >= 3;
        }

        if (earned) {
          newlyUnlocked.add(a);
          alreadyUnlocked.add(a.id);
        }
      }

      if (newlyUnlocked.isNotEmpty) {
        await prefs.setStringList(
            _prefsKey, alreadyUnlocked.toList());
        _saveToFirestore(user.uid, newlyUnlocked);
      }

      return newlyUnlocked;
    } catch (_) {
      return [];
    }
  }

  void _saveToFirestore(
      String uid, List<Achievement> achievements) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(uid);

      int totalXpReward = 0;
      for (final a in achievements) {
        batch.set(
          userRef.collection('achievements').doc(a.id),
          {
            'name': a.name,
            'description': a.description,
            'category': a.category,
            'rarity': a.rarity,
            'xpReward': a.xpReward,
            'unlockedAt': FieldValue.serverTimestamp(),
          },
        );
        totalXpReward += a.xpReward;
      }

      if (totalXpReward > 0) {
        batch.update(userRef, {
          'xp': FieldValue.increment(totalXpReward),
        });
      }

      await batch.commit();
    } catch (_) {}
  }

  /// Get set of unlocked achievement IDs from local cache.
  Future<Set<String>> getUnlockedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return Set<String>.from(prefs.getStringList(_prefsKey) ?? []);
  }
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String category;
  final String rarity;
  final int xpReward;
  final String icon;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.xpReward,
    required this.icon,
  });
}
