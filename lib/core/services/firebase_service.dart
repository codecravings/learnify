import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Singleton service providing access to Firebase instances.
class FirebaseService {
  FirebaseService._internal();

  static final FirebaseService _instance = FirebaseService._internal();

  static FirebaseService get instance => _instance;

  factory FirebaseService() => _instance;

  bool _initialized = false;

  /// Whether Firebase has been initialized.
  bool get isInitialized => _initialized;

  /// Firestore database instance.
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Firebase Auth instance.
  FirebaseAuth get auth => FirebaseAuth.instance;

  /// Initializes Firebase. Safe to call multiple times; only the first
  /// invocation performs actual initialization.
  Future<void> initialize() async {
    if (_initialized) return;

    await Firebase.initializeApp();

    // Enable Firestore offline persistence.
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    _initialized = true;
  }
}
