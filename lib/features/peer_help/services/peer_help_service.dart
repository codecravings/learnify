import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/feed_service.dart';
import '../../forum/services/forum_service.dart';
import '../../../models/forum_post_model.dart';

/// Wraps ForumService with XP rewards for the Peer Help / Ask & Answer feature.
class PeerHelpService {
  PeerHelpService._();
  static final instance = PeerHelpService._();

  final _forum = ForumService();
  final _users = FirebaseFirestore.instance.collection('users');

  /// Categories for peer help questions.
  static const categories = [
    'math',
    'physics',
    'chemistry',
    'biology',
    'coding',
    'logic',
    'general',
  ];

  /// Ask a new question. Awards XP to the asker.
  Future<String> askQuestion({
    required String title,
    required String content,
    required String category,
    List<String> tags = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    final post = ForumPostModel(
      id: '',
      title: title,
      content: content,
      authorId: user.uid,
      authorUsername: user.displayName ?? 'Learner',
      category: category,
      tags: tags,
      createdAt: DateTime.now(),
    );

    final postId = await _forum.createPost(post);

    // Award XP (fire-and-forget)
    _awardXP(user.uid, AppConstants.xpAskQuestion);

    // Post to feed
    FeedService.instance.post(
      action: 'asked_question',
      detail: 'Asked: $title',
    );

    return postId;
  }

  /// Submit an answer to a question. Awards XP for contributing.
  Future<String> submitAnswer(String postId, String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    final solId = await _forum.addSolution(postId, {
      'content': content,
      'authorId': user.uid,
      'authorName': user.displayName ?? 'Learner',
    });

    // Increment tutor stats
    _incrementTutorStat(user.uid, 'answersGiven');

    return solId;
  }

  /// Accept an answer. Awards XP to the answerer.
  Future<void> acceptAnswer({
    required String postId,
    required String solutionId,
    required String answerAuthorId,
  }) async {
    await _forum.acceptSolution(postId, solutionId);

    // Award XP to the answerer
    _awardXP(answerAuthorId, AppConstants.xpAcceptedAnswer);

    // Update tutor stats
    _incrementTutorStat(answerAuthorId, 'answersAccepted');
  }

  /// Upvote an answer. Awards small XP to the answer author.
  Future<void> upvoteAnswer({
    required String postId,
    required String voterId,
    required String answerAuthorId,
  }) async {
    await _forum.upvotePost(postId, voterId);
    _awardXP(answerAuthorId, AppConstants.xpAnswerUpvote);
  }

  /// Stream posts, optionally filtered by category.
  Stream<QuerySnapshot<Map<String, dynamic>>> postsStream({String? category}) {
    return _forum.postsStream(category: category);
  }

  /// Stream solutions for a post.
  Stream<QuerySnapshot<Map<String, dynamic>>> solutionsStream(String postId) {
    return _forum.solutionsStream(postId);
  }

  /// Get a single post.
  Future<ForumPostModel?> getPost(String postId) => _forum.getPost(postId);

  /// Get tutor stats for a user.
  Future<Map<String, int>> getTutorStats(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      final stats = doc.data()?['tutorStats'] as Map<String, dynamic>?;
      if (stats == null) return {'questionsAsked': 0, 'answersGiven': 0, 'answersAccepted': 0};
      return {
        'questionsAsked': (stats['questionsAsked'] as num?)?.toInt() ?? 0,
        'answersGiven': (stats['answersGiven'] as num?)?.toInt() ?? 0,
        'answersAccepted': (stats['answersAccepted'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {'questionsAsked': 0, 'answersGiven': 0, 'answersAccepted': 0};
    }
  }

  void _awardXP(String uid, int amount) async {
    try {
      await _users.doc(uid).update({'xp': FieldValue.increment(amount)});
    } catch (_) {}
  }

  void _incrementTutorStat(String uid, String field) async {
    try {
      await _users.doc(uid).update({
        'tutorStats.$field': FieldValue.increment(1),
      });
    } catch (_) {}
  }
}
