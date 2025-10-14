import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_service.g.dart';

/// Service for Firebase Authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in anonymously
  Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// Ensure user is authenticated (sign in anonymously if not)
  Future<User> ensureAuthenticated() async {
    User? user = _auth.currentUser;

    if (user == null) {
      final credential = await signInAnonymously();
      user = credential.user;
    }

    if (user == null) {
      throw Exception('Failed to authenticate user');
    }

    return user;
  }
}

@riverpod
AuthService authService(AuthServiceRef ref) {
  return AuthService();
}

/// Provider for auth state changes
@riverpod
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
}

/// Provider for current user
@riverpod
class CurrentUser extends _$CurrentUser {
  @override
  User? build() {
    // Listen to auth state changes
    ref.listen(authStateChangesProvider, (_, next) {
      next.whenData((user) {
        state = user;
      });
    });

    return ref.watch(authServiceProvider).currentUser;
  }
}
