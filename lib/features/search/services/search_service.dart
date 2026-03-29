import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';
import '../models/search_results.dart';

/// Unified search service that queries across challenges, forum posts,
/// and user profiles.
class SearchService {
  SearchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseService.instance.firestore;

  final FirebaseFirestore _firestore;

  // ---------------------------------------------------------------------------
  // Unified search
  // ---------------------------------------------------------------------------

  /// Searches challenges, forum posts, and users in parallel and returns
  /// an aggregated [SearchResults] object.
  Future<SearchResults> searchAll(String query) async {
    final normalised = query.toLowerCase().trim();
    if (normalised.isEmpty) {
      return SearchResults(
        challenges: [],
        posts: [],
        users: [],
        query: query,
      );
    }

    final results = await Future.wait([
      _searchCollection('challenges', normalised),
      _searchCollection('forum_posts', normalised),
      _searchUsersByName(normalised),
    ]);

    return SearchResults(
      challenges: results[0],
      posts: results[1],
      users: results[2],
      query: query,
    );
  }

  // ---------------------------------------------------------------------------
  // Individual search methods
  // ---------------------------------------------------------------------------

  /// Searches challenges by keyword, with optional [filters].
  ///
  /// Supported filter keys: `subject`, `difficulty`, `type`.
  Future<List<Map<String, dynamic>>> searchChallenges(
    String query, {
    Map<String, dynamic>? filters,
    int limit = 20,
  }) async {
    final normalised = query.toLowerCase().trim();

    Query<Map<String, dynamic>> ref = _firestore.collection('challenges');

    if (normalised.isNotEmpty) {
      ref = ref.where('searchTerms', arrayContains: normalised);
    }

    if (filters != null) {
      if (filters.containsKey('subject')) {
        ref = ref.where('subject', isEqualTo: filters['subject']);
      }
      if (filters.containsKey('difficulty')) {
        ref = ref.where('difficulty', isEqualTo: filters['difficulty']);
      }
      if (filters.containsKey('type')) {
        ref = ref.where('type', isEqualTo: filters['type']);
      }
    }

    final snapshot = await ref.limit(limit).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Searches users by username prefix.
  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    final normalised = query.trim();
    if (normalised.isEmpty) return [];

    // Use a range query on the `username` field to emulate prefix search.
    final end = '${normalised.substring(0, normalised.length - 1)}'
        '${String.fromCharCode(normalised.codeUnitAt(normalised.length - 1) + 1)}';

    final snapshot = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: normalised)
        .where('username', isLessThan: end)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Searches forum posts by keyword.
  Future<List<Map<String, dynamic>>> searchForumPosts(
    String query, {
    int limit = 20,
  }) async {
    final normalised = query.toLowerCase().trim();
    if (normalised.isEmpty) return [];

    final snapshot = await _firestore
        .collection('forum_posts')
        .where('searchTerms', arrayContains: normalised)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _searchCollection(
    String collection,
    String normalised,
  ) async {
    final snapshot = await _firestore
        .collection(collection)
        .where('searchTerms', arrayContains: normalised)
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _searchUsersByName(
    String normalised,
  ) async {
    final end = '${normalised.substring(0, normalised.length - 1)}'
        '${String.fromCharCode(normalised.codeUnitAt(normalised.length - 1) + 1)}';

    final snapshot = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: normalised)
        .where('username', isLessThan: end)
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
