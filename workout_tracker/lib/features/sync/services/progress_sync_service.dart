import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import 'auth_service.dart';

part 'progress_sync_service.g.dart';

/// Service for syncing user progress between local DB and Firestore
/// This is a BIDIRECTIONAL sync: Local DB ↔ Firestore (user-specific)
class ProgressSyncService {
  final firestore.FirebaseFirestore _firestore;
  final AppDatabase _database;
  final AuthService _authService;

  ProgressSyncService(this._firestore, this._database, this._authService);

  /// Add a completed set to the sync queue for upload
  Future<void> enqueueCompletedSet(String completedSetId) async {
    try {
      await _database.into(_database.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: 'sync_${DateTime.now().millisecondsSinceEpoch}_$completedSetId',
          entityType: 'completed_set',
          entityId: completedSetId,
          operation: 'create',
          data: completedSetId, // Just store the ID, actual data is in completed_sets table
          createdAt: DateTime.now(),
          synced: const Value(false),
        ),
      );
      debugPrint('[ProgressSyncService] Enqueued completed set: $completedSetId');
    } catch (e) {
      debugPrint('[ProgressSyncService] Error enqueueing completed set: $e');
      // Don't rethrow - sync will happen on next auto-flush
    }
  }

  /// Upload completed sets from local DB to Firestore (batched)
  Future<void> uploadCompletedSets({int batchSize = 20}) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('[ProgressSyncService] Starting completed sets upload...');

      // Get all unsynced completed sets
      final unsyncedSets = await (_database.select(_database.completedSets)
            ..where((tbl) => tbl.syncedAt.isNull()))
          .get();

      if (unsyncedSets.isEmpty) {
        debugPrint('[ProgressSyncService] No unsynced sets to upload');
        return;
      }

      debugPrint('[ProgressSyncService] Found ${unsyncedSets.length} unsynced sets');

      // Process in batches
      for (var i = 0; i < unsyncedSets.length; i += batchSize) {
        final batch = unsyncedSets.skip(i).take(batchSize).toList();
        await _uploadSetBatch(userId, batch);
        debugPrint('[ProgressSyncService] Uploaded batch ${i ~/ batchSize + 1} (${batch.length} sets)');
      }

      debugPrint('[ProgressSyncService] Completed sets upload complete');
    } catch (e, stackTrace) {
      debugPrint('[ProgressSyncService] Error uploading completed sets: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Upload a batch of completed sets to Firestore
  Future<void> _uploadSetBatch(String userId, List<CompletedSet> sets) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    for (final set in sets) {
      final docRef = _firestore
          .collection('user_progress')
          .doc(userId)
          .collection('completed_sets')
          .doc(set.id);

      batch.set(docRef, {
        'userId': userId,
        'planId': set.planId,
        'weekId': set.weekId,
        'dayId': set.dayId,
        'workoutId': set.workoutId,
        'workoutName': set.workoutName,
        'setNumber': set.setNumber,
        'weight': set.weight,
        'reps': set.reps,
        'duration': set.duration,
        'completedAt': firestore.Timestamp.fromDate(set.completedAt),
        'workoutAlternativeId': set.workoutAlternativeId,
        'updatedAt': firestore.Timestamp.fromDate(now),
      });
    }

    // Commit batch to Firestore
    await batch.commit();

    // Update local syncedAt timestamps
    for (final set in sets) {
      await (_database.update(_database.completedSets)
            ..where((tbl) => tbl.id.equals(set.id)))
          .write(
        CompletedSetsCompanion(
          syncedAt: Value(now),
        ),
      );
    }
  }

  /// Download completed sets from Firestore to local DB
  Future<void> downloadCompletedSets({DateTime? since}) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('[ProgressSyncService] Starting completed sets download...');

      var query = _firestore
          .collection('user_progress')
          .doc(userId)
          .collection('completed_sets')
          .orderBy('completedAt', descending: true);

      // Only fetch sets since last sync if provided
      if (since != null) {
        query = query.where('completedAt', isGreaterThan: firestore.Timestamp.fromDate(since));
      }

      final snapshot = await query.get();

      debugPrint('[ProgressSyncService] Found ${snapshot.docs.length} sets to download');

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Check if set already exists locally
        final existingSet = await (_database.select(_database.completedSets)
              ..where((tbl) => tbl.id.equals(doc.id)))
            .getSingleOrNull();

        final completedAt = (data['completedAt'] as firestore.Timestamp).toDate();
        final updatedAt = data['updatedAt'] != null
            ? (data['updatedAt'] as firestore.Timestamp).toDate()
            : completedAt;

        if (existingSet == null) {
          // Insert new set
          await _database.into(_database.completedSets).insert(
            CompletedSetsCompanion.insert(
              id: doc.id,
              userId: data['userId'] as String,
              planId: data['planId'] as String,
              weekId: data['weekId'] as String,
              dayId: data['dayId'] as String,
              workoutId: data['workoutId'] as String,
              workoutName: data['workoutName'] as String,
              setNumber: data['setNumber'] as int,
              weight: Value(data['weight'] as double?),
              reps: Value(data['reps'] as int?),
              duration: Value(data['duration'] as int?),
              completedAt: completedAt,
              syncedAt: Value(updatedAt),
              workoutAlternativeId: Value(data['workoutAlternativeId'] as String?),
            ),
          );
        } else {
          // Conflict resolution: last-write-wins (compare updatedAt)
          final localUpdatedAt = existingSet.syncedAt ?? existingSet.completedAt;
          if (updatedAt.isAfter(localUpdatedAt)) {
            // Firestore version is newer, update local
            await (_database.update(_database.completedSets)
                  ..where((tbl) => tbl.id.equals(doc.id)))
                .write(
              CompletedSetsCompanion(
                weight: Value(data['weight'] as double?),
                reps: Value(data['reps'] as int?),
                duration: Value(data['duration'] as int?),
                completedAt: Value(completedAt),
                syncedAt: Value(updatedAt),
              ),
            );
          }
        }
      }

      debugPrint('[ProgressSyncService] Completed sets download complete');
    } catch (e, stackTrace) {
      debugPrint('[ProgressSyncService] Error downloading completed sets: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sync user profile from local to Firestore
  Future<void> uploadUserProfile() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('[ProgressSyncService] Uploading user profile...');

      // Get local user profile
      final profile = await (_database.select(_database.userProfiles)
            ..where((tbl) => tbl.userId.equals(userId)))
          .getSingleOrNull();

      if (profile == null) {
        debugPrint('[ProgressSyncService] No local user profile found');
        return;
      }

      // Upload to Firestore
      await _firestore.collection('users').doc(userId).set({
        'userId': userId,
        'displayName': profile.displayName,
        'email': profile.email,
        'currentPlanId': profile.currentPlanId,
        'currentWeekNumber': profile.currentWeekNumber,
        'currentDayNumber': profile.currentDayNumber,
        'createdAt': firestore.Timestamp.fromDate(profile.createdAt),
        'updatedAt': firestore.Timestamp.fromDate(DateTime.now()),
      }, firestore.SetOptions(merge: true));

      debugPrint('[ProgressSyncService] User profile upload complete');
    } catch (e, stackTrace) {
      debugPrint('[ProgressSyncService] Error uploading user profile: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Download user profile from Firestore to local DB
  Future<void> downloadUserProfile() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('[ProgressSyncService] Downloading user profile...');

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        debugPrint('[ProgressSyncService] No Firestore user profile found');
        return;
      }

      final data = doc.data()!;
      final createdAt = (data['createdAt'] as firestore.Timestamp).toDate();
      final updatedAt = (data['updatedAt'] as firestore.Timestamp).toDate();

      // Check if local profile exists
      final existingProfile = await (_database.select(_database.userProfiles)
            ..where((tbl) => tbl.userId.equals(userId)))
          .getSingleOrNull();

      if (existingProfile == null) {
        // Insert new profile
        await _database.into(_database.userProfiles).insert(
          UserProfilesCompanion.insert(
            userId: userId,
            displayName: data['displayName'] as String,
            email: Value(data['email'] as String?),
            currentPlanId: Value(data['currentPlanId'] as String?),
            currentWeekNumber: Value(data['currentWeekNumber'] as int?),
            currentDayNumber: Value(data['currentDayNumber'] as int?),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
      } else {
        // Conflict resolution: last-write-wins
        if (updatedAt.isAfter(existingProfile.updatedAt)) {
          await (_database.update(_database.userProfiles)
                ..where((tbl) => tbl.userId.equals(userId)))
              .write(
            UserProfilesCompanion(
              displayName: Value(data['displayName'] as String),
              email: Value(data['email'] as String?),
              currentPlanId: Value(data['currentPlanId'] as String?),
              currentWeekNumber: Value(data['currentWeekNumber'] as int?),
              currentDayNumber: Value(data['currentDayNumber'] as int?),
              updatedAt: Value(updatedAt),
            ),
          );
        }
      }

      debugPrint('[ProgressSyncService] User profile download complete');
    } catch (e, stackTrace) {
      debugPrint('[ProgressSyncService] Error downloading user profile: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Full bidirectional progress sync
  Future<void> syncProgress() async {
    try {
      debugPrint('[ProgressSyncService] Starting full progress sync...');

      // Get last sync timestamp from local profile
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final profile = await (_database.select(_database.userProfiles)
            ..where((tbl) => tbl.userId.equals(userId)))
          .getSingleOrNull();

      final lastSync = profile?.syncLastProgressSync;

      // 1. Download progress from Firestore (fetch only new data if last sync exists)
      await downloadUserProfile();
      await downloadCompletedSets(since: lastSync);

      // 2. Upload local progress to Firestore
      await uploadUserProfile();
      await uploadCompletedSets();

      // 3. Update last sync timestamp
      final now = DateTime.now();
      if (profile != null) {
        await (_database.update(_database.userProfiles)
              ..where((tbl) => tbl.userId.equals(userId)))
            .write(
          UserProfilesCompanion(
            syncLastProgressSync: Value(now),
          ),
        );
      }

      debugPrint('[ProgressSyncService] Full progress sync complete');
    } catch (e, stackTrace) {
      debugPrint('[ProgressSyncService] Error in full progress sync: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Clean up old progress data (retain only last 2 cycles)
  Future<void> cleanupOldProgress(String planId, int weeksPerCycle) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('[ProgressSyncService] Cleaning up old progress data...');

      final retentionWeeks = weeksPerCycle * 2;
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionWeeks * 7));

      // Delete local completed sets older than cutoff
      final deletedLocal = await (_database.delete(_database.completedSets)
            ..where((tbl) =>
                tbl.userId.equals(userId) &
                tbl.planId.equals(planId) &
                tbl.completedAt.isSmallerThanValue(cutoffDate)))
          .go();

      debugPrint('[ProgressSyncService] Deleted $deletedLocal old sets from local DB');

      // Delete from Firestore
      final oldSetsSnapshot = await _firestore
          .collection('user_progress')
          .doc(userId)
          .collection('completed_sets')
          .where('planId', isEqualTo: planId)
          .where('completedAt', isLessThan: firestore.Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in oldSetsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('[ProgressSyncService] Deleted ${oldSetsSnapshot.docs.length} old sets from Firestore');
      debugPrint('[ProgressSyncService] Cleanup complete');
    } catch (e, stackTrace) {
      debugPrint('[ProgressSyncService] Error cleaning up old progress: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

@riverpod
ProgressSyncService progressSyncService(Ref ref) {
  final firestoreInstance = firestore.FirebaseFirestore.instance;
  final database = ref.watch(databaseProvider);
  final authService = ref.watch(authServiceProvider);
  return ProgressSyncService(firestoreInstance, database, authService);
}
