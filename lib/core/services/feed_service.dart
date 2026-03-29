import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Social activity feed — writes learning events to Firestore `feed` collection.
/// Supports reactions, comments, and real-time streaming.
class FeedService {
  FeedService._();
  static final instance = FeedService._();

  static const _collection = 'feed';

  /// All supported reaction type keys.
  static const reactionTypes = ['fire', 'brain', 'clap', 'perfect', 'heart'];

  /// Post an activity to the feed.
  void post({
    required String action,
    required String detail,
    String? topicName,
    int? accuracy,
    String? imageUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection(_collection).add({
        'uid': user.uid,
        'displayName': user.displayName ?? 'Learner',
        'photoURL': user.photoURL,
        'action': action,
        'detail': detail,
        if (topicName != null) 'topicName': topicName,
        if (accuracy != null) 'accuracy': accuracy,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'reactions': {
          'fire': <String>[],
          'brain': <String>[],
          'clap': <String>[],
          'perfect': <String>[],
          'heart': <String>[],
        },
        'reactionCount': 0,
        // Keep legacy fields for backward compat
        'likes': <String>[],
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Real-time stream of recent feed items.
  Stream<QuerySnapshot<Map<String, dynamic>>> feedStream({int limit = 30}) {
    return FirebaseFirestore.instance
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Stream feed posts only from a set of followed user UIDs.
  Stream<QuerySnapshot<Map<String, dynamic>>> followingFeedStream(
    List<String> followingUids, {
    int limit = 30,
  }) {
    if (followingUids.isEmpty) {
      // Return an empty stream
      return FirebaseFirestore.instance
          .collection(_collection)
          .where('uid', isEqualTo: '__none__')
          .limit(1)
          .snapshots();
    }
    // Firestore whereIn supports max 30 values
    return FirebaseFirestore.instance
        .collection(_collection)
        .where('uid', whereIn: followingUids.take(30).toList())
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Toggle a reaction on a feed post. User can only have one reaction per post.
  /// Returns the reaction type that is now active (null if removed).
  Future<String?> toggleReaction(String postId, String reactionType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final ref =
        FirebaseFirestore.instance.collection(_collection).doc(postId);

    try {
      final doc = await ref.get();
      final data = doc.data();
      if (data == null) return null;

      // Read the reactions map (or build from legacy likes)
      final reactions = <String, List<String>>{};
      final reactionsRaw = data['reactions'] as Map<String, dynamic>?;

      if (reactionsRaw != null) {
        for (final key in reactionTypes) {
          reactions[key] = List<String>.from(reactionsRaw[key] ?? []);
        }
      } else {
        // Legacy: convert likes to heart reactions
        for (final key in reactionTypes) {
          reactions[key] = <String>[];
        }
        reactions['heart'] = List<String>.from(data['likes'] ?? []);
      }

      // Find current reaction
      String? currentReaction;
      for (final key in reactionTypes) {
        if (reactions[key]!.contains(user.uid)) {
          currentReaction = key;
          break;
        }
      }

      String? newReaction;

      if (currentReaction == reactionType) {
        // Tapping same reaction — remove it
        reactions[reactionType]!.remove(user.uid);
        newReaction = null;
      } else {
        // Remove from old reaction if any
        if (currentReaction != null) {
          reactions[currentReaction]!.remove(user.uid);
        }
        // Add to new reaction
        reactions[reactionType]!.add(user.uid);
        newReaction = reactionType;
      }

      // Count total
      int total = 0;
      for (final key in reactionTypes) {
        total += reactions[key]!.length;
      }

      await ref.update({
        'reactions': reactions,
        'reactionCount': total,
        // Keep legacy fields in sync (heart = likes)
        'likes': reactions['heart'],
        'likeCount': total,
      });

      return newReaction;
    } catch (_) {
      return null;
    }
  }

  /// Toggle like on a feed post (legacy). Returns new like state.
  Future<bool> toggleLike(String postId) async {
    final result = await toggleReaction(postId, 'heart');
    return result == 'heart';
  }

  /// Add a comment to a feed post.
  Future<void> addComment(String postId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;

    try {
      final ref =
          FirebaseFirestore.instance.collection(_collection).doc(postId);

      await ref.collection('comments').add({
        'uid': user.uid,
        'displayName': user.displayName ?? 'Learner',
        'photoURL': user.photoURL,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await ref.update({
        'commentCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Stream comments for a post.
  Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream(String postId) {
    return FirebaseFirestore.instance
        .collection(_collection)
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(50)
        .snapshots();
  }
}
