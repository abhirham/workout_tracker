import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'template_sync_service.dart';

part 'initial_sync_service.g.dart';

/// Service for handling the initial one-time sync from Firestore
/// This ensures the local database is populated with data from Firestore on first login
class InitialSyncService {
  final TemplateSyncService _templateSyncService;
  static const String _syncCompletedKey = 'hasCompletedInitialSync';

  InitialSyncService(this._templateSyncService);

  /// Check if initial sync has been completed
  Future<bool> hasCompletedInitialSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncCompletedKey) ?? false;
  }

  /// Mark initial sync as completed
  Future<void> _markSyncCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncCompletedKey, true);
  }

  /// Perform initial sync from Firestore
  /// Downloads all global workouts and workout plans to local database
  Future<void> performInitialSync() async {
    try {
      debugPrint('[InitialSyncService] Starting initial sync from Firestore...');

      // Check if sync already completed
      final hasCompleted = await hasCompletedInitialSync();
      if (hasCompleted) {
        debugPrint('[InitialSyncService] Initial sync already completed, skipping');
        return;
      }

      // Sync all templates from Firestore
      await _templateSyncService.syncAll();

      // Mark sync as completed
      await _markSyncCompleted();

      debugPrint('[InitialSyncService] Initial sync completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[InitialSyncService] Error during initial sync: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Force a re-sync (clears the sync flag and syncs again)
  /// Useful for testing or manual refresh
  Future<void> forceResync() async {
    debugPrint('[InitialSyncService] Forcing re-sync...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncCompletedKey);
    await performInitialSync();
  }
}

@riverpod
InitialSyncService initialSyncService(InitialSyncServiceRef ref) {
  final templateSyncService = ref.watch(templateSyncServiceProvider);
  return InitialSyncService(templateSyncService);
}
