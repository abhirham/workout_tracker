import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'progress_sync_service.dart';
import 'template_sync_service.dart';

part 'sync_queue_processor.g.dart';

/// Service for processing the sync queue with batching and retry logic
class SyncQueueProcessor {
  final AppDatabase _database;
  final AuthService _authService;
  final ConnectivityService _connectivityService;
  final ProgressSyncService _progressSyncService;
  final TemplateSyncService _templateSyncService;

  Timer? _autoFlushTimer;
  bool _isProcessing = false;

  static const int _batchSize = 20;
  static const Duration _autoFlushInterval = Duration(seconds: 60);
  static const Duration _maxRetryDelay = Duration(minutes: 5);
  static const int _maxRetries = 5;

  SyncQueueProcessor(
    this._database,
    this._authService,
    this._connectivityService,
    this._progressSyncService,
    this._templateSyncService,
  );

  /// Start the sync queue processor with auto-flush
  void start() {
    debugPrint('[SyncQueueProcessor] Starting sync queue processor...');

    // Auto-flush every 60 seconds
    _autoFlushTimer = Timer.periodic(_autoFlushInterval, (_) {
      processQueue();
    });

    // Listen to connectivity changes and trigger sync when online
    _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('[SyncQueueProcessor] Connectivity restored, processing queue...');
        processQueue();
      }
    });

    debugPrint('[SyncQueueProcessor] Sync queue processor started');
  }

  /// Stop the sync queue processor
  void stop() {
    debugPrint('[SyncQueueProcessor] Stopping sync queue processor...');
    _autoFlushTimer?.cancel();
    _autoFlushTimer = null;
    debugPrint('[SyncQueueProcessor] Sync queue processor stopped');
  }

  /// Process the sync queue (flush to Firestore)
  Future<void> processQueue() async {
    if (_isProcessing) {
      debugPrint('[SyncQueueProcessor] Already processing queue, skipping...');
      return;
    }

    // Check connectivity
    final isOnline = await _connectivityService.isOnline();
    if (!isOnline) {
      debugPrint('[SyncQueueProcessor] Offline, skipping queue processing');
      return;
    }

    // Check authentication
    if (_authService.currentUserId == null) {
      debugPrint('[SyncQueueProcessor] User not authenticated, skipping queue processing');
      return;
    }

    _isProcessing = true;

    try {
      debugPrint('[SyncQueueProcessor] Processing sync queue...');

      // Get all unsynced queue items
      final queueItems = await (_database.select(_database.syncQueue)
            ..where((tbl) => tbl.synced.equals(false))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
          .get();

      if (queueItems.isEmpty) {
        debugPrint('[SyncQueueProcessor] No items in sync queue');
        return;
      }

      debugPrint('[SyncQueueProcessor] Found ${queueItems.length} items in sync queue');

      // Group items by entity type
      final completedSetItems = queueItems
          .where((item) => item.entityType == 'completed_set')
          .toList();
      final profileItems = queueItems
          .where((item) => item.entityType == 'user_profile')
          .toList();

      // Process completed sets in batches
      if (completedSetItems.isNotEmpty) {
        await _processCompletedSets(completedSetItems);
      }

      // Process user profile updates
      if (profileItems.isNotEmpty) {
        await _processUserProfiles(profileItems);
      }

      debugPrint('[SyncQueueProcessor] Queue processing complete');
    } catch (e, stackTrace) {
      debugPrint('[SyncQueueProcessor] Error processing queue: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      _isProcessing = false;
    }
  }

  /// Process completed sets from the queue
  Future<void> _processCompletedSets(List<SyncQueueData> items) async {
    debugPrint('[SyncQueueProcessor] Processing ${items.length} completed sets...');

    try {
      // Upload completed sets using the progress sync service
      await _progressSyncService.uploadCompletedSets(batchSize: _batchSize);

      // Mark queue items as synced
      for (final item in items) {
        await (_database.update(_database.syncQueue)
              ..where((tbl) => tbl.id.equals(item.id)))
            .write(
          SyncQueueCompanion(
            synced: const Value(true),
          ),
        );
      }

      debugPrint('[SyncQueueProcessor] Completed sets processed successfully');
    } catch (e, stackTrace) {
      debugPrint('[SyncQueueProcessor] Error processing completed sets: $e');
      debugPrint('Stack trace: $stackTrace');

      // Retry logic with exponential backoff
      await _retryFailedItems(items);
    }
  }

  /// Process user profile updates from the queue
  Future<void> _processUserProfiles(List<SyncQueueData> items) async {
    debugPrint('[SyncQueueProcessor] Processing ${items.length} user profile updates...');

    try {
      // Upload user profile using the progress sync service
      await _progressSyncService.uploadUserProfile();

      // Mark queue items as synced
      for (final item in items) {
        await (_database.update(_database.syncQueue)
              ..where((tbl) => tbl.id.equals(item.id)))
            .write(
          SyncQueueCompanion(
            synced: const Value(true),
          ),
        );
      }

      debugPrint('[SyncQueueProcessor] User profile updates processed successfully');
    } catch (e, stackTrace) {
      debugPrint('[SyncQueueProcessor] Error processing user profile updates: $e');
      debugPrint('Stack trace: $stackTrace');

      // Retry logic
      await _retryFailedItems(items);
    }
  }

  /// Retry failed items with exponential backoff
  Future<void> _retryFailedItems(List<SyncQueueData> items) async {
    for (final item in items) {
      // Calculate retry count (parse from data JSON if stored)
      final retryCount = 0; // TODO: Track retry count in queue item data

      if (retryCount >= _maxRetries) {
        debugPrint('[SyncQueueProcessor] Max retries reached for item ${item.id}, marking as failed');
        // TODO: Mark item as permanently failed or move to dead-letter queue
        continue;
      }

      // Exponential backoff: 2^retryCount seconds, max 5 minutes
      final delaySeconds = (1 << retryCount).clamp(1, _maxRetryDelay.inSeconds);
      debugPrint('[SyncQueueProcessor] Will retry item ${item.id} in $delaySeconds seconds');

      // Schedule retry (simplified - in production, use a more robust job scheduler)
      Timer(Duration(seconds: delaySeconds), () {
        processQueue();
      });
    }
  }

  /// Flush queue on app pause/background (call this from lifecycle hooks)
  Future<void> flushOnPause() async {
    debugPrint('[SyncQueueProcessor] Flushing queue on app pause...');
    await processQueue();
  }

  /// Clean up old synced queue items (retention: 7 days)
  Future<void> cleanupSyncedItems() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      final deletedCount = await (_database.delete(_database.syncQueue)
            ..where((tbl) =>
                tbl.synced.equals(true) &
                tbl.createdAt.isSmallerOrEqualValue(cutoffDate)))
          .go();

      debugPrint('[SyncQueueProcessor] Deleted $deletedCount old synced queue items');
    } catch (e, stackTrace) {
      debugPrint('[SyncQueueProcessor] Error cleaning up synced items: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Sync templates from Firestore (admin → user download)
  Future<void> syncTemplates() async {
    try {
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) {
        debugPrint('[SyncQueueProcessor] Offline, skipping template sync');
        return;
      }

      debugPrint('[SyncQueueProcessor] Starting template sync...');
      await _templateSyncService.syncAll();
      debugPrint('[SyncQueueProcessor] Template sync complete');
    } catch (e, stackTrace) {
      debugPrint('[SyncQueueProcessor] Error syncing templates: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Full bidirectional progress sync (download + upload)
  Future<void> syncProgress() async {
    try {
      final isOnline = await _connectivityService.isOnline();
      if (!isOnline) {
        debugPrint('[SyncQueueProcessor] Offline, skipping progress sync');
        return;
      }

      debugPrint('[SyncQueueProcessor] Starting progress sync...');
      await _progressSyncService.syncProgress();
      debugPrint('[SyncQueueProcessor] Progress sync complete');
    } catch (e, stackTrace) {
      debugPrint('[SyncQueueProcessor] Error syncing progress: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Full sync: templates + progress + queue processing
  Future<void> fullSync() async {
    try {
      debugPrint('[SyncQueueProcessor] Starting full sync...');

      // 1. Sync templates (download only)
      await syncTemplates();

      // 2. Process queue (upload pending changes)
      await processQueue();

      // 3. Sync progress (bidirectional)
      await syncProgress();

      // 4. Cleanup old queue items
      await cleanupSyncedItems();

      debugPrint('[SyncQueueProcessor] Full sync complete');
    } catch (e, stackTrace) {
      debugPrint('[SyncQueueProcessor] Error in full sync: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}

@riverpod
SyncQueueProcessor syncQueueProcessor(Ref ref) {
  final database = ref.watch(databaseProvider);
  final authService = ref.watch(authServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  final progressSyncService = ref.watch(progressSyncServiceProvider);
  final templateSyncService = ref.watch(templateSyncServiceProvider);

  return SyncQueueProcessor(
    database,
    authService,
    connectivityService,
    progressSyncService,
    templateSyncService,
  );
}
