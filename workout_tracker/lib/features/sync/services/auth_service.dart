import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_service.g.dart';

/// Service for Firebase Authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        throw Exception('Sign-in cancelled by user');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Store user ID in shared preferences for persistence
      if (userCredential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Get user ID from auth or shared preferences
  Future<String?> getUserId() async {
    // First try to get from current auth state
    if (_auth.currentUser != null) {
      return _auth.currentUser!.uid;
    }

    // Fallback to shared preferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();

      // Clear stored user ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
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
