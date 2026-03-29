import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../models/battle_model.dart';
import '../services/bot_service.dart';

/// Service responsible for real-time battle lifecycle, matchmaking,
/// answer submission, and spectator streaming.
class BattleService {
  BattleService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseService.instance.firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _battlesCollection =>
      _firestore.collection('battles');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Real-time Matchmaking
  // ---------------------------------------------------------------------------

  /// Creates a matchmaking entry and waits for an opponent.
  /// Returns the battle ID once matched, or null if cancelled.
  /// Stores serialized questions in the battle doc so both players see the same set.
  Future<String> createOrJoinMatch({
    required String mode,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    debugPrint('[MATCH] uid=$uid, mode=$mode');

    // 0. Clean up MY old stale waiting battles first
    final myOld = await _battlesCollection
        .where('player1Id', isEqualTo: uid)
        .where('status', isEqualTo: 'waiting')
        .get();
    for (final doc in myOld.docs) {
      debugPrint('[MATCH] Deleting my stale battle ${doc.id}');
      await doc.reference.delete();
    }

    // 1. Look for an existing waiting battle in this mode from ANOTHER player
    final waiting = await _battlesCollection
        .where('mode', isEqualTo: mode)
        .where('status', isEqualTo: 'waiting')
        .limit(5)
        .get();

    debugPrint('[MATCH] Found ${waiting.docs.length} waiting battles');

    for (final doc in waiting.docs) {
      final data = doc.data();
      final p1 = data['player1Id'] as String? ?? '';
      debugPrint('[MATCH] Battle ${doc.id}: p1=$p1, uid=$uid, skip=${p1 == uid}');
      if (p1 == uid) continue; // Don't match yourself

      // Join this battle
      try {
        await doc.reference.update({
          'player2Id': uid,
          'status': 'in_progress',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[MATCH] Joined battle ${doc.id}!');
        return doc.id;
      } catch (e) {
        debugPrint('[MATCH] Failed to join ${doc.id}: $e');
        continue;
      }
    }

    // 2. No match found → create a new waiting battle with questions
    final questions = BotService.instance.getQuestions(mode, count: 7);
    final questionsData = questions.map((q) => {
      'question': q.question,
      'options': q.options,
      'correctIndex': q.correctIndex,
      'explanation': q.explanation ?? '',
      'difficulty': q.difficulty,
      'category': q.category,
    }).toList();

    final docRef = _battlesCollection.doc();
    debugPrint('[MATCH] Creating new battle ${docRef.id}');
    await docRef.set({
      'id': docRef.id,
      'mode': mode,
      'player1Id': uid,
      'player2Id': '',
      'status': 'waiting',
      'player1Score': 0,
      'player2Score': 0,
      'player1Answered': 0,
      'player2Answered': 0,
      'currentRound': 0,
      'totalRounds': 7,
      'questions': questionsData,
      'answers': {},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Listens to a battle doc and returns a stream of its data.
  Stream<Map<String, dynamic>?> battleStream(String battleId) {
    return _battlesCollection.doc(battleId).snapshots().map((snap) => snap.data());
  }

  /// Submit an answer for the current player.
  Future<void> submitAnswer({
    required String battleId,
    required int questionIndex,
    required int selectedOption,
    required bool isCorrect,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final battleDoc = await _battlesCollection.doc(battleId).get();
    final data = battleDoc.data();
    if (data == null) return;

    final isPlayer1 = data['player1Id'] == uid;
    final scoreField = isPlayer1 ? 'player1Score' : 'player2Score';
    final answeredField = isPlayer1 ? 'player1Answered' : 'player2Answered';

    final updates = <String, dynamic>{
      'answers.${uid}_$questionIndex': {
        'selectedOption': selectedOption,
        'isCorrect': isCorrect,
        'timestamp': FieldValue.serverTimestamp(),
      },
      answeredField: FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isCorrect) {
      updates[scoreField] = FieldValue.increment(1);
    }

    await _battlesCollection.doc(battleId).update(updates);
  }

  /// End the battle and record the result.
  Future<void> endBattle(String battleId) async {
    final doc = await _battlesCollection.doc(battleId).get();
    final data = doc.data();
    if (data == null) return;

    final p1Score = data['player1Score'] as int? ?? 0;
    final p2Score = data['player2Score'] as int? ?? 0;

    String? winnerId;
    if (p1Score > p2Score) {
      winnerId = data['player1Id'];
    } else if (p2Score > p1Score) {
      winnerId = data['player2Id'];
    }

    await _battlesCollection.doc(battleId).update({
      'status': 'completed',
      'winnerId': winnerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Award XP
    final p1 = data['player1Id'] as String? ?? '';
    final p2 = data['player2Id'] as String? ?? '';
    final users = _firestore.collection('users');

    if (p1.isNotEmpty) {
      final xp = winnerId == p1 ? 50 + p1Score * 10 : 10 + p1Score * 5;
      await users.doc(p1).update({'xp': FieldValue.increment(xp)});
    }
    if (p2.isNotEmpty) {
      final xp = winnerId == p2 ? 50 + p2Score * 10 : 10 + p2Score * 5;
      await users.doc(p2).update({'xp': FieldValue.increment(xp)});
    }
  }

  /// Cancel a waiting battle (remove from queue).
  Future<void> cancelMatch(String battleId) async {
    final doc = await _battlesCollection.doc(battleId).get();
    final data = doc.data();
    if (data != null && data['status'] == 'waiting') {
      await _battlesCollection.doc(battleId).delete();
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy methods (kept for other screens)
  // ---------------------------------------------------------------------------

  Future<BattleModel> createBattle(String mode, String player1Id) async {
    final docRef = _battlesCollection.doc();
    final now = DateTime.now();
    final battle = BattleModel(
      id: docRef.id, mode: mode, player1Id: player1Id, player2Id: '',
      status: 'waiting', player1Score: 0, player2Score: 0,
      currentRound: 0, totalRounds: 5, answers: const {},
      createdAt: now, updatedAt: now,
    );
    await docRef.set(battle.toJson());
    return battle;
  }

  Future<void> joinBattle(String battleId, String player2Id) async {
    await _battlesCollection.doc(battleId).update({
      'player2Id': player2Id,
      'status': 'in_progress',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<BattleModel> getBattleStream(String battleId) {
    return _battlesCollection.doc(battleId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) throw Exception('Battle not found');
      return BattleModel.fromJson(data);
    });
  }

  Stream<List<BattleModel>> getActiveBattles() {
    return _battlesCollection
        .where('status', isEqualTo: 'in_progress')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BattleModel.fromJson(doc.data()))
            .toList());
  }

  Stream<List<BattleModel>> getSpectatorBattles() {
    return _battlesCollection
        .where('status', isEqualTo: 'in_progress')
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BattleModel.fromJson(doc.data()))
            .where((b) => b.player2Id.isNotEmpty)
            .toList());
  }
}
