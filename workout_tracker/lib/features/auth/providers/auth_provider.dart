import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workout_tracker/features/sync/services/auth_service.dart';

part 'auth_provider.g.dart';

/// Provider for current auth state
/// Returns the current Firebase User or null if not authenticated
@riverpod
Stream<User?> authState(AuthStateRef ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
}

/// Provider for current user
/// This is a convenient way to access the current user synchronously
@riverpod
class CurrentAuthUser extends _$CurrentAuthUser {
  @override
  User? build() {
    // Listen to auth state changes
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        state = user;
      });
    });

    return ref.watch(authServiceProvider).currentUser;
  }
}

/// Provider for user profile data
@riverpod
class UserProfile extends _$UserProfile {
  @override
  ({String? name, String? email, String? photoUrl}) build() {
    final user = ref.watch(currentAuthUserProvider);

    if (user == null) {
      return (name: null, email: null, photoUrl: null);
    }

    return (
      name: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }
}

/// Provider to check if user is authenticated
@riverpod
bool isAuthenticated(IsAuthenticatedRef ref) {
  final user = ref.watch(currentAuthUserProvider);
  return user != null;
}

/// Provider for sign out action
@riverpod
class SignOutController extends _$SignOutController {
  @override
  FutureOr<void> build() {
    // Nothing to build initially
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    });
  }
}
