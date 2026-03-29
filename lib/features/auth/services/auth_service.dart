import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/firebase_service.dart';
import '../../../models/user_model.dart';

/// Handles all authentication operations and user-profile management.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseService.instance.auth,
        _firestore = firestore ?? FirebaseService.instance.firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Collection reference for user profiles.
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // ---------------------------------------------------------------------------
  // Auth state
  // ---------------------------------------------------------------------------

  /// Stream that emits whenever the authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the currently signed-in [User], or `null`.
  User? getCurrentUser() => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // Email / password
  // ---------------------------------------------------------------------------

  /// Signs in with [email] and [password].
  /// Returns the authenticated [User].
  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last active timestamp (only if profile exists).
    if (credential.user != null) {
      try {
        final doc = await _usersCollection.doc(credential.user!.uid).get();
        if (doc.exists) {
          await _usersCollection.doc(credential.user!.uid).update({
            'lastActive': DateTime.now().toIso8601String(),
          });
        } else {
          await createUserProfile(
            credential.user!,
            credential.user!.displayName ?? credential.user!.email?.split('@').first ?? 'User',
          );
        }
      } catch (e) {
        debugPrint('[AUTH] Firestore error on email sign-in: $e');
      }
    }

    return credential.user;
  }

  /// Creates a new account with [email], [password], and [username].
  /// A Firestore user profile is automatically created.
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(username);
      await createUserProfile(user, username);
    }

    return user;
  }

  // ---------------------------------------------------------------------------
  // Google sign-in
  // ---------------------------------------------------------------------------

  /// Signs in using a Google account.
  /// Creates a Firestore profile on first sign-in.
  Future<User?> signInWithGoogle() async {
    UserCredential userCredential;

    if (kIsWeb) {
      // Web: use Firebase Auth popup (no client ID needed)
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      userCredential = await _auth.signInWithPopup(googleProvider);
    } else {
      // Mobile: use google_sign_in package
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      userCredential = await _auth.signInWithCredential(credential);
    }

    final user = userCredential.user;

    if (user != null) {
      try {
        final doc = await _usersCollection.doc(user.uid).get();
        if (!doc.exists) {
          debugPrint('[AUTH] Creating profile for Google user ${user.uid}');
          await createUserProfile(
            user,
            user.displayName ?? 'User',
          );
          debugPrint('[AUTH] Profile created successfully');
        } else {
          await _usersCollection.doc(user.uid).update({
            'lastActive': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('[AUTH] Firestore error on Google sign-in: $e');
      }
    }

    return user;
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Firestore profile
  // ---------------------------------------------------------------------------

  /// Ensures the current user has a Firestore profile.
  /// Always writes with merge:true — no read needed, idempotent, never overwrites existing data.
  /// Retries up to 3 times with backoff if Firestore is temporarily unavailable.
  Future<void> ensureProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final username = user.displayName ?? user.email?.split('@').first ?? 'User';

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
        // Always write with merge — creates if missing, no-op if exists
        // Only sets fields that don't exist yet (merge preserves existing data)
        await _usersCollection.doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'username': username,
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'xp': 0,
          'currentStreak': 0,
          'interests': <String>[],
          'onboardingComplete': true,
        }, SetOptions(merge: true));

        // Also update lastActive every time (this always overwrites)
        await _usersCollection.doc(user.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });

        debugPrint('[AUTH] ensureProfileExists OK for ${user.uid}');
        return;
      } catch (e) {
        debugPrint('[AUTH] ensureProfileExists attempt ${attempt + 1} error: $e');
      }
    }
  }

  /// Creates a [UserModel] document in Firestore for [user].
  /// Uses merge:true so it never fails on existing docs.
  Future<void> createUserProfile(User user, String username) async {
    final now = DateTime.now();
    final userModel = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      username: username,
      photoUrl: user.photoURL ?? '',
      createdAt: now,
      lastActive: now,
    );

    await _usersCollection.doc(user.uid).set(
      userModel.toJson(),
      SetOptions(merge: true),
    );
    debugPrint('[AUTH] Profile written for ${user.uid} (merge:true)');
  }

  /// Fetches the [UserModel] for [uid] from Firestore.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromJson(doc.data()!);
  }

  /// Updates specific fields on a user profile.
  Future<void> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    await _usersCollection.doc(uid).update(data);
  }
}
