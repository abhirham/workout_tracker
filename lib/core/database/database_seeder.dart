import 'package:drift/drift.dart';
import 'app_database.dart';
import 'package:uuid/uuid.dart';

/// Service to seed the database with initial workout template data
class DatabaseSeeder {
  final AppDatabase _database;
  static const _seedVersionKey = 'seed_version';
  static const _currentSeedVersion = 1;

  DatabaseSeeder(this._database);

  /// Check if database needs seeding and seed if necessary
  Future<void> seedIfNeeded() async {
    // Check if already seeded by looking for any workout plans
    final existingPlans = await _database.select(_database.workoutPlans).get();

    if (existingPlans.isEmpty) {
      await _seedWorkoutTemplates();
    }
  }

  Future<void> _seedWorkoutTemplates() async {
    const uuid = Uuid();

    // Create a single workout plan
    final planId = uuid.v4();
    await _database.into(_database.workoutPlans).insert(
      WorkoutPlansCompanion.insert(
        id: planId,
        name: 'Starting Strength Program',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Create 12 weeks (3 months program)
    for (int weekNum = 1; weekNum <= 12; weekNum++) {
      final weekId = uuid.v4();
      await _database.into(_database.weeks).insert(
        WeeksCompanion.insert(
          id: weekId,
          planId: planId,
          weekNumber: weekNum,
          name: 'Week $weekNum',
        ),
      );

      // Create 4 training days per week
      final days = [
        {'num': 1, 'name': 'Upper Push', 'workouts': _getUpperPushWorkouts(weekNum)},
        {'num': 2, 'name': 'Lower Body', 'workouts': _getLowerBodyWorkouts(weekNum)},
        {'num': 3, 'name': 'Back & Pull', 'workouts': _getBackPullWorkouts(weekNum)},
        {'num': 4, 'name': 'Arms', 'workouts': _getArmsWorkouts(weekNum)},
      ];

      for (final day in days) {
        // Create unique day ID per week: week1_day1, week2_day1, etc.
        final dayId = 'week${weekNum}_day_${day['num']}';
        await _database.into(_database.days).insert(
          DaysCompanion.insert(
            id: dayId,
            weekId: weekId,
            dayNumber: day['num'] as int,
            name: day['name'] as String,
          ),
          mode: InsertMode.insertOrReplace,
        );

        // Add workouts for this day
        final workouts = day['workouts'] as List<Map<String, dynamic>>;
        for (int i = 0; i < workouts.length; i++) {
          final workout = workouts[i];
          final workoutId = '${dayId}_workout_${i + 1}';

          await _database.into(_database.workouts).insert(
            WorkoutsCompanion.insert(
              id: workoutId,
              dayId: dayId,
              name: workout['name'] as String,
              order: i,
              notes: Value(workout['notes'] as String?),
              defaultSets: (workout['weights'] as List).length,
            ),
            mode: InsertMode.insertOrReplace,
          );

          // Add set templates
          final weights = workout['weights'] as List<double>;
          for (int setNum = 0; setNum < weights.length; setNum++) {
            await _database.into(_database.setTemplates).insert(
              SetTemplatesCompanion.insert(
                id: '${workoutId}_set_${setNum + 1}',
                workoutId: workoutId,
                setNumber: setNum + 1,
                suggestedReps: Value(_getTargetReps(weekNum)),
                suggestedWeight: Value(weights[setNum]),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }

          // Add timer config (45 seconds rest between sets)
          await _database.into(_database.timerConfigs).insert(
            TimerConfigsCompanion.insert(
              id: '${workoutId}_timer',
              workoutId: Value(workoutId),
              durationSeconds: 45,
              isActive: true,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
    }
  }

  int _getTargetReps(int weekNumber) {
    // Week cycle: week1=12, week2=9, week3=6, week4=3, then repeat
    final cycleWeek = ((weekNumber - 1) % 4) + 1;
    switch (cycleWeek) {
      case 1:
        return 12;
      case 2:
        return 9;
      case 3:
        return 6;
      case 4:
        return 3;
      default:
        return 12;
    }
  }

  List<Map<String, dynamic>> _getUpperPushWorkouts(int weekNum) {
    return [
      {'name': 'Bench Press', 'notes': 'Focus on slow eccentric', 'weights': [135.0, 155.0, 175.0]},
      {'name': 'Overhead Press', 'notes': null, 'weights': [75.0, 85.0, 95.0]},
      {'name': 'Incline Dumbbell Press', 'notes': '30 degree angle', 'weights': [60.0, 70.0]},
    ];
  }

  List<Map<String, dynamic>> _getLowerBodyWorkouts(int weekNum) {
    return [
      {'name': 'Squat', 'notes': 'Full depth', 'weights': [185.0, 205.0, 225.0]},
      {'name': 'Romanian Deadlift', 'notes': 'Keep back straight', 'weights': [135.0, 155.0, 175.0]},
      {'name': 'Leg Press', 'notes': null, 'weights': [270.0, 315.0, 360.0]},
    ];
  }

  List<Map<String, dynamic>> _getBackPullWorkouts(int weekNum) {
    return [
      {'name': 'Deadlift', 'notes': 'Use lifting straps if needed', 'weights': [225.0, 275.0, 315.0]},
      {'name': 'Barbell Row', 'notes': 'Pull to lower chest', 'weights': [135.0, 155.0, 175.0]},
      {'name': 'Lat Pulldown', 'notes': null, 'weights': [120.0, 135.0, 150.0]},
    ];
  }

  List<Map<String, dynamic>> _getArmsWorkouts(int weekNum) {
    return [
      {'name': 'Close Grip Bench', 'notes': 'Elbows tucked', 'weights': [115.0, 135.0, 155.0]},
      {'name': 'Dips', 'notes': 'Bodyweight or add weight', 'weights': [0.0, 25.0, 45.0]},
      {'name': 'Tricep Extension', 'notes': null, 'weights': [70.0, 80.0, 90.0]},
    ];
  }
}
