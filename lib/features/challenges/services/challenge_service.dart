import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../models/challenge_model.dart';

/// Service for creating, querying, and solving challenges stored in Firestore.
class ChallengeService {
  ChallengeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseService.instance.firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _challengesCollection =>
      _firestore.collection('challenges');

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Persists a new [challenge] to Firestore and returns the generated ID.
  Future<String> createChallenge(ChallengeModel challenge) async {
    final docRef = _challengesCollection.doc();
    final data = challenge.toJson();
    data['id'] = docRef.id;
    data['createdAt'] = DateTime.now().toIso8601String();

    await docRef.set(data);
    return docRef.id;
  }

  /// Fetches a single challenge by [id].
  Future<ChallengeModel?> getChallenge(String id) async {
    final doc = await _challengesCollection.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return ChallengeModel.fromJson(doc.data()!);
  }

  /// Returns a paginated list of challenges matching optional [filters].
  ///
  /// Supported filter keys: `subject`, `difficulty`, `type`.
  /// [limit] controls page size and [lastDocId] is used for cursor-based
  /// pagination.
  Future<List<ChallengeModel>> getChallenges({
    Map<String, dynamic>? filters,
    int limit = 20,
    String? lastDocId,
  }) async {
    Query<Map<String, dynamic>> query = _challengesCollection;

    if (filters != null) {
      if (filters.containsKey('subject')) {
        query = query.where('subject', isEqualTo: filters['subject']);
      }
      if (filters.containsKey('difficulty')) {
        query = query.where('difficulty', isEqualTo: filters['difficulty']);
      }
      if (filters.containsKey('type')) {
        query = query.where('type', isEqualTo: filters['type']);
      }
    }

    query = query.orderBy('createdAt', descending: true);

    // Cursor-based pagination.
    if (lastDocId != null) {
      final lastDoc = await _challengesCollection.doc(lastDocId).get();
      if (lastDoc.exists) {
        query = query.startAfterDocument(lastDoc);
      }
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ChallengeModel.fromJson(doc.data()))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Solving
  // ---------------------------------------------------------------------------

  /// Submits a [userId]'s [answer] to the challenge identified by
  /// [challengeId]. Returns `true` if the answer is correct.
  Future<bool> submitSolution(
    String challengeId,
    String userId,
    String answer,
  ) async {
    final doc = await _challengesCollection.doc(challengeId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Challenge not found');
    }

    final challenge = ChallengeModel.fromJson(doc.data()!);
    final isCorrect =
        answer.trim().toLowerCase() == challenge.answer.trim().toLowerCase();

    // Always increment attempt count.
    await incrementAttemptCount(challengeId);

    if (isCorrect) {
      await incrementSolveCount(challengeId);

      // Record the solve on the user's profile.
      await _firestore.collection('users').doc(userId).update({
        'solvedChallenges': FieldValue.arrayUnion([challengeId]),
        'xp': FieldValue.increment(challenge.xpReward),
      });
    }

    // Store the submission.
    await _challengesCollection
        .doc(challengeId)
        .collection('submissions')
        .add({
      'userId': userId,
      'answer': answer,
      'isCorrect': isCorrect,
      'submittedAt': DateTime.now().toIso8601String(),
    });

    return isCorrect;
  }

  // ---------------------------------------------------------------------------
  // Hints
  // ---------------------------------------------------------------------------

  /// Returns the hint for [challengeId] at the given [hintLevel] (1-based).
  Future<String> getHint(String challengeId, int hintLevel) async {
    final doc = await _challengesCollection.doc(challengeId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Challenge not found');
    }

    final hints = List<String>.from(doc.data()!['hints'] ?? []);
    if (hintLevel < 1 || hintLevel > hints.length) {
      throw RangeError('Hint level $hintLevel is out of range '
          '(1..${hints.length})');
    }

    return hints[hintLevel - 1];
  }

  // ---------------------------------------------------------------------------
  // Search & filtering
  // ---------------------------------------------------------------------------

  /// Full-text keyword search over challenge titles and descriptions.
  Future<List<ChallengeModel>> searchChallenges(String query) async {
    final normalised = query.toLowerCase();

    // Firestore does not natively support full-text search, so we rely on a
    // `searchTerms` array field populated at write time.
    final snapshot = await _challengesCollection
        .where('searchTerms', arrayContains: normalised)
        .limit(30)
        .get();

    return snapshot.docs
        .map((doc) => ChallengeModel.fromJson(doc.data()))
        .toList();
  }

  /// Returns all challenges authored by [userId].
  Future<List<ChallengeModel>> getChallengesByCreator(String userId) async {
    final snapshot = await _challengesCollection
        .where('creatorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ChallengeModel.fromJson(doc.data()))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Counters
  // ---------------------------------------------------------------------------

  /// Atomically increments the solve count for [challengeId].
  Future<void> incrementSolveCount(String challengeId) async {
    await _challengesCollection.doc(challengeId).update({
      'solveCount': FieldValue.increment(1),
    });
  }

  /// Atomically increments the attempt count for [challengeId].
  Future<void> incrementAttemptCount(String challengeId) async {
    await _challengesCollection.doc(challengeId).update({
      'attemptCount': FieldValue.increment(1),
    });
  }
}
