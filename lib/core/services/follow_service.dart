import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Singleton service for follow/unfollow functionality.
/// Uses Firestore arrays on user documents for hackathon-scale (< 1000 followers).
class FollowService {
  FollowService._();
  static final instance = FollowService._();

  final _users = FirebaseFirestore.instance.collection('users');

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  /// Follow a user. Updates both users' documents in a batch.
  Future<void> follow(String targetUid) async {
    final myUid = _myUid;
    if (myUid == null || myUid == targetUid) return;

    final batch = FirebaseFirestore.instance.batch();

    batch.set(_users.doc(myUid), {
      'following': FieldValue.arrayUnion([targetUid]),
      'followingCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    batch.set(_users.doc(targetUid), {
      'followers': FieldValue.arrayUnion([myUid]),
      'followerCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Unfollow a user.
  Future<void> unfollow(String targetUid) async {
    final myUid = _myUid;
    if (myUid == null || myUid == targetUid) return;

    final batch = FirebaseFirestore.instance.batch();

    batch.set(_users.doc(myUid), {
      'following': FieldValue.arrayRemove([targetUid]),
      'followingCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));
    batch.set(_users.doc(targetUid), {
      'followers': FieldValue.arrayRemove([myUid]),
      'followerCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Check if the current user follows [targetUid].
  Future<bool> isFollowing(String targetUid) async {
    final myUid = _myUid;
    if (myUid == null) return false;

    final doc = await _users.doc(myUid).get();
    final following = List<String>.from(doc.data()?['following'] ?? []);
    return following.contains(targetUid);
  }

  /// Get the list of UIDs the current user follows.
  Future<List<String>> getFollowingList() async {
    final myUid = _myUid;
    if (myUid == null) return [];

    final doc = await _users.doc(myUid).get();
    return List<String>.from(doc.data()?['following'] ?? []);
  }

  /// Get suggested users based on shared interests.
  /// Returns up to [limit] user docs that share interests but are not followed.
  Future<List<Map<String, dynamic>>> getSuggestedUsers({
    List<String> myInterests = const [],
    int limit = 5,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return [];

    try {
      // Get current following list
      final myDoc = await _users.doc(myUid).get();
      final following = List<String>.from(myDoc.data()?['following'] ?? []);

      Query<Map<String, dynamic>> query = _users;

      if (myInterests.isNotEmpty) {
        query = query.where('interests', arrayContainsAny: myInterests.take(10).toList());
      }

      final snapshot = await query.limit(limit + following.length + 1).get();

      return snapshot.docs
          .where((doc) => doc.id != myUid && !following.contains(doc.id))
          .take(limit)
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (_) {
      return [];
    }
  }
}
