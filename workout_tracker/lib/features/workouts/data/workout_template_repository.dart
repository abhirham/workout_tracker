import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// Model for a workout with its sets loaded from database
class WorkoutWithSets {
  final Workout workout;
  final List<SetTemplate> sets;
  final TimerConfig? timerConfig;

  WorkoutWithSets({
    required this.workout,
    required this.sets,
    this.timerConfig,
  });
}

/// Repository for loading workout template data from database
class WorkoutTemplateRepository {
  final AppDatabase _database;

  WorkoutTemplateRepository(this._database);

  /// Get all workouts for a specific day with their set templates
  Future<List<WorkoutWithSets>> getWorkoutsForDay(String dayId) async {
    // Get all workouts for this day, ordered by 'order' field
    final workouts = await (_database.select(_database.workouts)
          ..where((tbl) => tbl.dayId.equals(dayId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.order)]))
        .get();

    // Load sets and timer for each workout
    final workoutsWithSets = <WorkoutWithSets>[];
    for (final workout in workouts) {
      final sets = await (_database.select(_database.setTemplates)
            ..where((tbl) => tbl.workoutId.equals(workout.id))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.setNumber)]))
          .get();

      final timerConfig = await (_database.select(_database.timerConfigs)
            ..where((tbl) => tbl.workoutId.equals(workout.id))
            ..limit(1))
          .getSingleOrNull();

      workoutsWithSets.add(WorkoutWithSets(
        workout: workout,
        sets: sets,
        timerConfig: timerConfig,
      ));
    }

    return workoutsWithSets;
  }

  /// Get a single workout with its sets
  Future<WorkoutWithSets?> getWorkoutById(String workoutId) async {
    final workout = await (_database.select(_database.workouts)
          ..where((tbl) => tbl.id.equals(workoutId)))
        .getSingleOrNull();

    if (workout == null) return null;

    final sets = await (_database.select(_database.setTemplates)
          ..where((tbl) => tbl.workoutId.equals(workoutId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.setNumber)]))
        .get();

    final timerConfig = await (_database.select(_database.timerConfigs)
          ..where((tbl) => tbl.workoutId.equals(workoutId))
          ..limit(1))
        .getSingleOrNull();

    return WorkoutWithSets(
      workout: workout,
      sets: sets,
      timerConfig: timerConfig,
    );
  }

  /// Get all workout plans
  Future<List<WorkoutPlan>> getAllPlans() async {
    return await _database.select(_database.workoutPlans).get();
  }

  /// Get all weeks for a plan
  Future<List<Week>> getWeeksForPlan(String planId) async {
    return await (_database.select(_database.weeks)
          ..where((tbl) => tbl.planId.equals(planId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.weekNumber)]))
        .get();
  }

  /// Get all days for a week
  Future<List<Day>> getDaysForWeek(String weekId) async {
    return await (_database.select(_database.days)
          ..where((tbl) => tbl.weekId.equals(weekId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]))
        .get();
  }

  /// Get a specific day
  Future<Day?> getDayById(String dayId) async {
    return await (_database.select(_database.days)
          ..where((tbl) => tbl.id.equals(dayId)))
        .getSingleOrNull();
  }

  /// Get timer duration for a workout (returns seconds)
  Future<int> getTimerDuration(String workoutId) async {
    final config = await (_database.select(_database.timerConfigs)
          ..where((tbl) => tbl.workoutId.equals(workoutId))
          ..limit(1))
        .getSingleOrNull();

    return config?.durationSeconds ?? 45; // Default 45 seconds
  }
}
