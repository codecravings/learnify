import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../../../models/forum_post_model.dart';

/// Service for managing forum posts and solutions in Firestore.
class ForumService {
  ForumService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseService.instance.firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _postsCollection =>
      _firestore.collection('forum_posts');

  // ---------------------------------------------------------------------------
  // Posts
  // ---------------------------------------------------------------------------

  /// Creates a new forum post. Returns the generated document ID.
  Future<String> createPost(ForumPostModel post) async {
    final docRef = _postsCollection.doc();
    final data = post.toJson();
    data['id'] = docRef.id;
    data['createdAt'] = DateTime.now().toIso8601String();
    data['updatedAt'] = DateTime.now().toIso8601String();
    data['upvotes'] = 0;
    data['downvotes'] = 0;
    data['solutionCount'] = 0;
    data['isResolved'] = false;

    await docRef.set(data);
    return docRef.id;
  }

  /// Retrieves a paginated list of posts, optionally filtered by [category].
  /// [page] is 1-based; each page returns up to [pageSize] items.
  Future<List<ForumPostModel>> getPosts({
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    Query<Map<String, dynamic>> query = _postsCollection;

    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    query = query.orderBy('createdAt', descending: true);

    // Offset-based pagination via limit.
    if (page > 1) {
      final previousPageSnapshot = await query.limit((page - 1) * pageSize).get();
      if (previousPageSnapshot.docs.isNotEmpty) {
        query = query.startAfterDocument(previousPageSnapshot.docs.last);
      }
    }

    final snapshot = await query.limit(pageSize).get();
    return snapshot.docs
        .map((doc) => ForumPostModel.fromJson(doc.data()))
        .toList();
  }

  /// Fetches a single post by [postId].
  Future<ForumPostModel?> getPost(String postId) async {
    final doc = await _postsCollection.doc(postId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ForumPostModel.fromJson(doc.data()!);
  }

  // ---------------------------------------------------------------------------
  // Solutions
  // ---------------------------------------------------------------------------

  /// Adds a solution to the post identified by [postId].
  /// [solution] should contain at least `authorId`, `content`.
  Future<String> addSolution(
    String postId,
    Map<String, dynamic> solution,
  ) async {
    final solRef = _postsCollection.doc(postId).collection('solutions').doc();
    solution['id'] = solRef.id;
    solution['createdAt'] = DateTime.now().toIso8601String();
    solution['upvotes'] = 0;
    solution['isAccepted'] = false;

    await solRef.set(solution);

    // Increment solution count on the parent post.
    await _postsCollection.doc(postId).update({
      'solutionCount': FieldValue.increment(1),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return solRef.id;
  }

  /// Marks [solutionId] as the accepted solution for [postId].
  Future<void> acceptSolution(String postId, String solutionId) async {
    final batch = _firestore.batch();

    // Mark the solution as accepted.
    batch.update(
      _postsCollection.doc(postId).collection('solutions').doc(solutionId),
      {'isAccepted': true},
    );

    // Mark the post as resolved.
    batch.update(
      _postsCollection.doc(postId),
      {
        'isResolved': true,
        'acceptedSolutionId': solutionId,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );

    await batch.commit();
  }

  /// Real-time stream of solutions for a post, ordered by creation time.
  Stream<QuerySnapshot<Map<String, dynamic>>> solutionsStream(String postId) {
    return _postsCollection
        .doc(postId)
        .collection('solutions')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Real-time stream of all posts, optionally filtered by category.
  Stream<QuerySnapshot<Map<String, dynamic>>> postsStream({String? category}) {
    Query<Map<String, dynamic>> query = _postsCollection;
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    return query.orderBy('createdAt', descending: true).limit(50).snapshots();
  }

  // ---------------------------------------------------------------------------
  // Voting
  // ---------------------------------------------------------------------------

  /// Upvotes the post identified by [postId].
  /// Uses a sub-collection to ensure one vote per user.
  Future<void> upvotePost(String postId, String userId) async {
    final voteRef =
        _postsCollection.doc(postId).collection('votes').doc(userId);
    final voteDoc = await voteRef.get();

    final batch = _firestore.batch();

    if (voteDoc.exists && voteDoc.data()?['type'] == 'up') {
      // Already upvoted -- remove the vote.
      batch.delete(voteRef);
      batch.update(_postsCollection.doc(postId), {
        'upvotes': FieldValue.increment(-1),
      });
    } else {
      if (voteDoc.exists && voteDoc.data()?['type'] == 'down') {
        // Switch from downvote to upvote.
        batch.update(_postsCollection.doc(postId), {
          'downvotes': FieldValue.increment(-1),
        });
      }
      batch.set(voteRef, {'type': 'up', 'userId': userId});
      batch.update(_postsCollection.doc(postId), {
        'upvotes': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  /// Downvotes the post identified by [postId].
  Future<void> downvotePost(String postId, String userId) async {
    final voteRef =
        _postsCollection.doc(postId).collection('votes').doc(userId);
    final voteDoc = await voteRef.get();

    final batch = _firestore.batch();

    if (voteDoc.exists && voteDoc.data()?['type'] == 'down') {
      // Already downvoted -- remove the vote.
      batch.delete(voteRef);
      batch.update(_postsCollection.doc(postId), {
        'downvotes': FieldValue.increment(-1),
      });
    } else {
      if (voteDoc.exists && voteDoc.data()?['type'] == 'up') {
        // Switch from upvote to downvote.
        batch.update(_postsCollection.doc(postId), {
          'upvotes': FieldValue.increment(-1),
        });
      }
      batch.set(voteRef, {'type': 'down', 'userId': userId});
      batch.update(_postsCollection.doc(postId), {
        'downvotes': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Searches posts by keyword using a `searchTerms` array field.
  Future<List<ForumPostModel>> searchPosts(String query) async {
    final normalised = query.toLowerCase();

    final snapshot = await _postsCollection
        .where('searchTerms', arrayContains: normalised)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    return snapshot.docs
        .map((doc) => ForumPostModel.fromJson(doc.data()))
        .toList();
  }
}
