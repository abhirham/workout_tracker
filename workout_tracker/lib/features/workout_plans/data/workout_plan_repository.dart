import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

part 'workout_plan_repository.g.dart';

/// Repository for managing workout plans from local database
class WorkoutPlanRepository {
  final AppDatabase _database;

  WorkoutPlanRepository(this._database);

  /// Get all active workout plans
  Future<List<WorkoutPlan>> getAllWorkoutPlans() async {
    return await _database.select(_database.workoutPlans).get();
  }

  /// Get a specific workout plan by ID
  Future<WorkoutPlan?> getWorkoutPlanById(String planId) async {
    return await (_database.select(_database.workoutPlans)
          ..where((tbl) => tbl.id.equals(planId)))
        .getSingleOrNull();
  }

  /// Get workout plan with total weeks count
  Future<Map<String, dynamic>?> getWorkoutPlanWithDetails(String planId) async {
    final plan = await getWorkoutPlanById(planId);
    if (plan == null) return null;

    // Count total weeks for this plan
    final weeksCount = await (_database.selectOnly(_database.weeks)
          ..addColumns([_database.weeks.id.count()])
          ..where(_database.weeks.planId.equals(planId)))
        .getSingle();

    return {
      'id': plan.id,
      'name': plan.name,
      'totalWeeks': weeksCount.read(_database.weeks.id.count()) ?? 0,
      'createdAt': plan.createdAt,
      'updatedAt': plan.updatedAt,
    };
  }

  /// Get all workout plans with their week counts
  Future<List<Map<String, dynamic>>> getAllWorkoutPlansWithDetails() async {
    final plans = await getAllWorkoutPlans();
    final plansWithDetails = <Map<String, dynamic>>[];

    for (final plan in plans) {
      final details = await getWorkoutPlanWithDetails(plan.id);
      if (details != null) {
        plansWithDetails.add(details);
      }
    }

    return plansWithDetails;
  }

  /// Stream of all workout plans (for real-time updates)
  Stream<List<WorkoutPlan>> watchAllWorkoutPlans() {
    return _database.select(_database.workoutPlans).watch();
  }
}

@riverpod
WorkoutPlanRepository workoutPlanRepository(Ref ref) {
  final database = ref.watch(databaseProvider);
  return WorkoutPlanRepository(database);
}

/// Provider to watch all workout plans with details
@riverpod
Future<List<Map<String, dynamic>>> workoutPlansWithDetails(Ref ref) async {
  final repository = ref.watch(workoutPlanRepositoryProvider);
  return await repository.getAllWorkoutPlansWithDetails();
}
