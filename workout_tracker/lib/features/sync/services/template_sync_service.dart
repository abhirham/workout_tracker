import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

part 'template_sync_service.g.dart';

/// Service for syncing workout templates from Firestore to local database
/// This is a ONE-WAY sync: Firestore (admin) → Local DB (user)
class TemplateSyncService {
  final FirebaseFirestore _firestore;
  final AppDatabase _database;

  TemplateSyncService(this._firestore, this._database);

  /// Helper to safely parse int from Firestore (handles both string and number)
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  /// Helper to safely parse double from Firestore (handles both string and number)
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is String) return double.tryParse(value);
    if (value is num) return value.toDouble();
    return null;
  }

  /// Sync all global workouts from Firestore to local DB
  Future<void> syncGlobalWorkouts() async {
    try {
      debugPrint('[TemplateSyncService] Starting global workouts sync...');

      final snapshot = await _firestore
          .collection('global_workouts')
          .where('isActive', isEqualTo: true)
          .get();

      debugPrint(
        '[TemplateSyncService] Found ${snapshot.docs.length} global workouts',
      );

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Parse muscle groups, equipment, and keywords from Firestore arrays
        final muscleGroups =
            (data['muscleGroups'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final equipment =
            (data['equipment'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final searchKeywords =
            (data['searchKeywords'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // Convert to CSV for local storage
        final muscleGroupsCsv = muscleGroups.join(',');
        final equipmentCsv = equipment.join(',');
        final searchKeywordsCsv = searchKeywords.join(',');

        // Normalize type to lowercase (Firestore may have "Weight"/"Timer")
        final workoutType = (data['type'] as String).toLowerCase();

        await _database
            .into(_database.globalWorkouts)
            .insertOnConflictUpdate(
              GlobalWorkoutsCompanion.insert(
                id: doc.id,
                name: data['name'] as String,
                type: workoutType,
                muscleGroups: muscleGroupsCsv,
                equipment: equipmentCsv,
                searchKeywords: searchKeywordsCsv,
                isActive: Value(data['isActive'] as bool? ?? true),
                createdAt: (data['createdAt'] as Timestamp).toDate(),
                updatedAt: (data['updatedAt'] as Timestamp).toDate(),
              ),
            );
      }

      debugPrint('[TemplateSyncService] Global workouts sync complete');
    } catch (e, stackTrace) {
      debugPrint('[TemplateSyncService] Error syncing global workouts: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sync a single workout plan from Firestore to local DB
  Future<void> syncWorkoutPlan(String planId) async {
    try {
      debugPrint('[TemplateSyncService] Syncing workout plan: $planId');

      // 1. Sync workout plan
      final planDoc = await _firestore
          .collection('workout_plans')
          .doc(planId)
          .get();
      if (!planDoc.exists) {
        throw Exception('Workout plan not found: $planId');
      }

      final planData = planDoc.data()!;
      await _database
          .into(_database.workoutPlans)
          .insertOnConflictUpdate(
            WorkoutPlansCompanion.insert(
              id: planId,
              name: planData['name'] as String,
              description: Value(planData['description'] as String?),
              totalWeeks: _parseInt(planData['totalWeeks']) ?? 1,
              isActive: Value(planData['isActive'] as bool? ?? true),
              createdAt: (planData['createdAt'] as Timestamp).toDate(),
              updatedAt: (planData['updatedAt'] as Timestamp).toDate(),
            ),
          );

      // 2. Sync weeks
      final weeksSnapshot = await _firestore
          .collection('workout_plans')
          .doc(planId)
          .collection('weeks')
          .get();

      for (final weekDoc in weeksSnapshot.docs) {
        final weekData = weekDoc.data();
        await _database
            .into(_database.weeks)
            .insertOnConflictUpdate(
              WeeksCompanion.insert(
                id: weekDoc.id,
                planId: planId,
                weekNumber: _parseInt(weekData['weekNumber']) ?? 1,
                name: weekData['name'] as String,
                createdAt: (weekData['createdAt'] as Timestamp).toDate(),
                updatedAt: (weekData['updatedAt'] as Timestamp).toDate(),
              ),
            );

        // 3. Sync days for this week
        final daysSnapshot = await _firestore
            .collection('workout_plans')
            .doc(planId)
            .collection('weeks')
            .doc(weekDoc.id)
            .collection('days')
            .get();

        for (final dayDoc in daysSnapshot.docs) {
          final dayData = dayDoc.data();
          await _database
              .into(_database.days)
              .insertOnConflictUpdate(
                DaysCompanion.insert(
                  id: dayDoc.id,
                  weekId: weekDoc.id,
                  dayNumber: _parseInt(dayData['dayNumber']) ?? 1,
                  name: dayData['name'] as String,
                  createdAt: (dayData['createdAt'] as Timestamp).toDate(),
                  updatedAt: (dayData['updatedAt'] as Timestamp).toDate(),
                ),
              );

          // 4. Sync workouts for this day
          final workoutsSnapshot = await _firestore
              .collection('workout_plans')
              .doc(planId)
              .collection('weeks')
              .doc(weekDoc.id)
              .collection('days')
              .doc(dayDoc.id)
              .collection('workouts')
              .get();

          for (final workoutDoc in workoutsSnapshot.docs) {
            final workoutData = workoutDoc.data();

            // Fetch global workout data to get the name
            final globalWorkoutId = workoutData['globalWorkoutId'] as String;
            final globalWorkoutDoc = await _firestore
                .collection('global_workouts')
                .doc(globalWorkoutId)
                .get();

            if (!globalWorkoutDoc.exists) {
              debugPrint(
                '[TemplateSyncService] Warning: Global workout not found: $globalWorkoutId. Skipping workout ${workoutDoc.id}',
              );
              continue;
            }

            final globalWorkoutData = globalWorkoutDoc.data()!;
            final workoutName = globalWorkoutData['name'] as String;

            // Parse baseWeight (single number) and alternativeWorkouts from Firestore
            final baseWeight = _parseDouble(workoutData['baseWeight']);
            final alternativeWorkouts =
                (workoutData['alternativeWorkouts'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList();

            // Convert alternativeWorkouts to CSV for local storage
            final alternativeWorkoutsCsv = alternativeWorkouts?.join(',');
            final numSets = _parseInt(workoutData['numSets']) ?? 3;
            await _database
                .into(_database.workouts)
                .insertOnConflictUpdate(
                  WorkoutsCompanion.insert(
                    id: workoutDoc.id,
                    planId: planId,
                    globalWorkoutId: globalWorkoutId,
                    dayId: dayDoc.id,
                    name: workoutName,
                    order: _parseInt(workoutData['order']) ?? 1,
                    numSets: numSets,
                    notes: Value(workoutData['notes'] as String?),
                    baseWeight: Value(baseWeight),
                    targetReps: Value(workoutData['targetReps'] as String?),
                    restTimerSeconds: Value(
                      _parseInt(workoutData['restTimerSeconds']),
                    ),
                    workoutDurationSeconds: Value(
                      _parseInt(workoutData['workoutDurationSeconds']),
                    ),
                    alternativeWorkouts: Value(alternativeWorkoutsCsv),
                    createdAt: (workoutData['createdAt'] as Timestamp).toDate(),
                    updatedAt: (workoutData['updatedAt'] as Timestamp).toDate(),
                  ),
                );

            // 5. Sync set templates
            // Generate set templates based on numSets (already extracted above)
            for (int setNum = 1; setNum <= numSets; setNum++) {
              await _database
                  .into(_database.setTemplates)
                  .insertOnConflictUpdate(
                    SetTemplatesCompanion.insert(
                      id: '${workoutDoc.id}_set_$setNum',
                      workoutId: workoutDoc.id,
                      setNumber: setNum,
                      suggestedReps: Value(null), // Will use targetReps from workout
                      suggestedWeight: Value(baseWeight), // All sets use same base weight
                      suggestedDuration: Value(
                        _parseInt(workoutData['workoutDurationSeconds']),
                      ),
                    ),
                  );
            }
          }
        }
      }

      debugPrint('[TemplateSyncService] Workout plan sync complete: $planId');
    } catch (e, stackTrace) {
      debugPrint('[TemplateSyncService] Error syncing workout plan: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sync all available workout plans for the user
  Future<void> syncAllWorkoutPlans() async {
    try {
      debugPrint('[TemplateSyncService] Syncing all workout plans...');

      final plansSnapshot = await _firestore
          .collection('workout_plans')
          .where('isActive', isEqualTo: true)
          .get();

      for (final planDoc in plansSnapshot.docs) {
        await syncWorkoutPlan(planDoc.id);
      }

      debugPrint('[TemplateSyncService] All workout plans synced');
    } catch (e, stackTrace) {
      debugPrint('[TemplateSyncService] Error syncing all workout plans: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Full template sync: global workouts + workout plans
  Future<void> syncAll() async {
    try {
      debugPrint('[TemplateSyncService] Starting full template sync...');

      await syncGlobalWorkouts();
      await syncAllWorkoutPlans();

      // Update last sync timestamp
      // TODO: Store last sync timestamp in UserProfile or SharedPreferences
      // final now = DateTime.now();

      debugPrint('[TemplateSyncService] Full template sync complete');
    } catch (e, stackTrace) {
      debugPrint('[TemplateSyncService] Error in full template sync: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

@riverpod
TemplateSyncService templateSyncService(TemplateSyncServiceRef ref) {
  final firestore = FirebaseFirestore.instance;
  final database = ref.watch(databaseProvider);
  return TemplateSyncService(firestore, database);
}
