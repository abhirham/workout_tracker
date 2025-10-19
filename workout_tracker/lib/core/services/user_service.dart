import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/sync/services/auth_service.dart';

part 'user_service.g.dart';

/// Central service to get current user ID
/// Provides a single source of truth for user identification across the app
class UserService {
  final AuthService _authService;

  UserService(this._authService);

  String? _cachedUserId;

  /// Get current user ID from auth provider or cache
  /// Returns null if no user is authenticated
  String? getCurrentUserId() {
    // First try to get from auth service
    final authUserId = _authService.currentUserId;
    if (authUserId != null) {
      _cachedUserId = authUserId;
      return authUserId;
    }

    // Return cached value if available
    return _cachedUserId;
  }

  /// Get current user ID, throwing an error if no user is authenticated
  /// Use this method when user ID is required for the operation
  String getCurrentUserIdOrThrow() {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('No user is currently authenticated. Please sign in.');
    }
    return userId;
  }

  /// Get user ID from auth or shared preferences (async fallback)
  /// Useful for initialization where auth state might not be immediately available
  Future<String?> getUserIdAsync() async {
    // First try to get from current auth state
    final authUserId = _authService.currentUserId;
    if (authUserId != null) {
      _cachedUserId = authUserId;
      return authUserId;
    }

    // Fallback to shared preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('userId');
      if (storedUserId != null) {
        _cachedUserId = storedUserId;
        return storedUserId;
      }
    } catch (e) {
      debugPrint('[UserService] Error getting userId from SharedPreferences: $e');
    }

    return null;
  }

  /// Clear cached user ID (call on sign out)
  void clearCache() {
    _cachedUserId = null;
  }
}

@riverpod
UserService userService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return UserService(authService);
}
