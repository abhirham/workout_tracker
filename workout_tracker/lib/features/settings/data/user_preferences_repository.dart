import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

/// Repository for managing user preferences (device-only settings)
class UserPreferencesRepository {
  final AppDatabase _db;

  UserPreferencesRepository(this._db);

  /// Get the user's preferred rest timer duration in seconds
  /// Returns 45 if no preference is set (default)
  Future<int> getDefaultRestTimer(String userId) async {
    final userProfile = await (_db.select(_db.userProfiles)
          ..where((tbl) => tbl.userId.equals(userId)))
        .getSingleOrNull();

    return userProfile?.defaultRestTimerSeconds ?? 45;
  }

  /// Update the user's preferred rest timer duration
  /// Duration must be between 5 and 300 seconds (5s to 5 minutes)
  /// Creates the user profile if it doesn't exist
  Future<void> updateDefaultRestTimer(String userId, int seconds) async {
    // Validate duration
    if (seconds < 5 || seconds > 300) {
      throw ArgumentError(
        'Rest timer duration must be between 5 and 300 seconds',
      );
    }

    // Check if user profile exists
    final existingProfile = await (_db.select(_db.userProfiles)
          ..where((tbl) => tbl.userId.equals(userId)))
        .getSingleOrNull();

    if (existingProfile == null) {
      // Profile doesn't exist - create it with the rest timer preference
      // This can happen for new users or after database migrations
      await _db.into(_db.userProfiles).insert(
            UserProfilesCompanion.insert(
              userId: userId,
              displayName: 'User', // Placeholder - should be updated by auth flow
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              defaultRestTimerSeconds: Value(seconds),
            ),
          );
    } else {
      // Profile exists - just update the preference
      await (_db.update(_db.userProfiles)
            ..where((tbl) => tbl.userId.equals(userId)))
          .write(
        UserProfilesCompanion(
          defaultRestTimerSeconds: Value(seconds),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Stream the user's rest timer preference for reactive UI
  Stream<int> watchDefaultRestTimer(String userId) {
    return (_db.select(_db.userProfiles)
          ..where((tbl) => tbl.userId.equals(userId)))
        .watchSingleOrNull()
        .map((profile) => profile?.defaultRestTimerSeconds ?? 45);
  }
}

/// Riverpod provider for UserPreferencesRepository
final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return UserPreferencesRepository(database);
});

/// Provider to watch the current user's rest timer preference
/// Returns a stream of the rest timer duration in seconds
final restTimerPreferenceProvider = StreamProvider.family<int, String>((ref, userId) {
  final repository = ref.watch(userPreferencesRepositoryProvider);
  return repository.watchDefaultRestTimer(userId);
});
