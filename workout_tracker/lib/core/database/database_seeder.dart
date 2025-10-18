import 'package:drift/drift.dart';
import 'app_database.dart';

/// Service to seed the database with initial workout template data
class DatabaseSeeder {
  final AppDatabase _database;

  DatabaseSeeder(this._database);

  /// Check if database needs seeding and seed if necessary
  Future<void> seedIfNeeded() async {
    // Check if already seeded by looking for any workout plans
    final existingPlans = await _database.select(_database.workoutPlans).get();

    if (existingPlans.isEmpty) {
      await _seedWorkoutTemplates();
    }
  }

  /// Delete all data and reseed from scratch
  Future<void> deleteAndReseed() async {
    // Delete all data in correct order (reverse of foreign key dependencies)
    await _database.delete(_database.completedSets).go();
    await _database.delete(_database.workoutProgressTable).go();
    await _database.delete(_database.workoutAlternatives).go();
    await _database.delete(_database.setTemplates).go();
    await _database.delete(_database.timerConfigs).go();
    await _database.delete(_database.workouts).go();
    await _database.delete(_database.days).go();
    await _database.delete(_database.weeks).go();
    await _database.delete(_database.workoutPlans).go();
    await _database.delete(_database.userProfiles).go();
    await _database.delete(_database.syncQueue).go();

    // Reseed with fresh data
    await _seedWorkoutTemplates();
  }

  Future<void> _seedWorkoutTemplates() async {
    // Step 1: Create global workouts library
    await _seedGlobalWorkouts();

    // Step 2: Create a single workout plan with fixed ID to match mock UI
    const planId = '1';  // Fixed ID to match WorkoutPlanListScreen mock data
    await _database.into(_database.workoutPlans).insert(
      WorkoutPlansCompanion.insert(
        id: planId,
        name: 'Beginner Strength Training',  // Match the mock plan name
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );

    // Create 8 weeks (2 phases of 4 weeks each)
    for (int weekNum = 1; weekNum <= 8; weekNum++) {
      final weekId = 'week_$weekNum';  // Use consistent format: week_1, week_2, etc.
      await _database.into(_database.weeks).insert(
        WeeksCompanion.insert(
          id: weekId,
          planId: planId,
          weekNumber: weekNum,
          name: 'Week $weekNum',
        ),
        mode: InsertMode.insertOrReplace,
      );

      // Create 4 training days per week
      final days = [
        {'num': 1, 'name': 'Chest & Triceps', 'workouts': _getDay1Workouts()},
        {'num': 2, 'name': 'Back & Biceps', 'workouts': _getDay2Workouts()},
        {'num': 3, 'name': 'Shoulders & Traps', 'workouts': _getDay3Workouts()},
        {'num': 4, 'name': 'Legs', 'workouts': _getDay4Workouts()},
      ];

      for (final day in days) {
        // Create unique day ID per week: week1_day_1, week2_day_1, etc.
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
          // Global workout ID (e.g., "bench-press")
          final globalWorkoutId = _normalizeWorkoutId(workout['name'] as String);
          // Unique workout instance ID per day (e.g., "week1_day_1_bench-press")
          final workoutId = '${dayId}_$globalWorkoutId';

          final baseWeights = workout['baseWeights'] as List<double>;
          final baseWeightsJson = baseWeights.join(',');
          final targetReps = _getTargetReps(weekNum);

          await _database.into(_database.workouts).insert(
            WorkoutsCompanion.insert(
              id: workoutId,
              planId: planId,  // Reference to workout plan
              globalWorkoutId: globalWorkoutId,  // Reference to global workout
              dayId: dayId,
              name: workout['name'] as String,
              order: i,
              notes: Value(workout['notes'] as String?),
              baseWeights: Value(baseWeightsJson),  // Store as JSON
              targetReps: Value(targetReps),  // Week-specific target reps
              restTimerSeconds: const Value(45),  // Default 45 seconds rest
              workoutDurationSeconds: const Value(null),  // Null for weight workouts
              alternativeWorkouts: const Value(null),  // No admin-defined alternatives yet
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrReplace,
          );

          // Add set templates with week-specific rep targets and calculated weights
          // Note: Set templates are still unique per day/week combo since they have week-specific weights
          for (int setNum = 0; setNum < baseWeights.length; setNum++) {
            final calculatedWeight = _calculateWeight(baseWeights[setNum], weekNum);
            final targetRepsInt = int.parse(targetReps);  // Parse string to int for SetTemplates

            await _database.into(_database.setTemplates).insert(
              SetTemplatesCompanion.insert(
                id: '${dayId}_${workoutId}_set_${setNum + 1}',
                workoutId: workoutId,
                setNumber: setNum + 1,
                suggestedReps: Value(targetRepsInt),
                suggestedWeight: Value(calculatedWeight),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }

          // Add timer config (45 seconds rest between sets)
          // Note: Timer configs could be shared, but we keep them per day/week for flexibility
          await _database.into(_database.timerConfigs).insert(
            TimerConfigsCompanion.insert(
              id: '${dayId}_${workoutId}_timer',
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

  /// Seed global workouts library
  Future<void> _seedGlobalWorkouts() async {
    final now = DateTime.now();
    final globalWorkouts = [
      // Day 1: Chest & Triceps
      {
        'id': 'bench-press',
        'name': 'Bench Press',
        'type': 'weight',
        'muscleGroups': ['chest', 'triceps'],
        'equipment': ['barbell', 'bench'],
        'searchKeywords': ['bench', 'press', 'chest', 'barbell']
      },
      {
        'id': 'incline-dumbbell-press',
        'name': 'Incline Dumbbell Press',
        'type': 'weight',
        'muscleGroups': ['chest', 'shoulders'],
        'equipment': ['dumbbells', 'bench'],
        'searchKeywords': ['incline', 'dumbbell', 'press', 'chest']
      },
      {
        'id': 'cable-flyes',
        'name': 'Cable Flyes',
        'type': 'weight',
        'muscleGroups': ['chest'],
        'equipment': ['cable'],
        'searchKeywords': ['cable', 'fly', 'flyes', 'chest']
      },
      {
        'id': 'tricep-dips',
        'name': 'Tricep Dips',
        'type': 'weight',
        'muscleGroups': ['triceps', 'chest'],
        'equipment': ['dip-bar'],
        'searchKeywords': ['tricep', 'dip', 'dips']
      },
      {
        'id': 'tricep-pushdown',
        'name': 'Tricep Pushdown',
        'type': 'weight',
        'muscleGroups': ['triceps'],
        'equipment': ['cable'],
        'searchKeywords': ['tricep', 'pushdown', 'cable']
      },

      // Day 2: Back & Biceps
      {
        'id': 'deadlift',
        'name': 'Deadlift',
        'type': 'weight',
        'muscleGroups': ['back', 'hamstrings', 'glutes'],
        'equipment': ['barbell'],
        'searchKeywords': ['deadlift', 'dead', 'lift', 'back']
      },
      {
        'id': 'pull-ups',
        'name': 'Pull-ups',
        'type': 'weight',
        'muscleGroups': ['back', 'biceps'],
        'equipment': ['pull-up-bar'],
        'searchKeywords': ['pull', 'up', 'pullup', 'back']
      },
      {
        'id': 'barbell-row',
        'name': 'Barbell Row',
        'type': 'weight',
        'muscleGroups': ['back'],
        'equipment': ['barbell'],
        'searchKeywords': ['barbell', 'row', 'back']
      },
      {
        'id': 'lat-pulldown',
        'name': 'Lat Pulldown',
        'type': 'weight',
        'muscleGroups': ['back'],
        'equipment': ['cable'],
        'searchKeywords': ['lat', 'pulldown', 'back', 'cable']
      },
      {
        'id': 'barbell-curl',
        'name': 'Barbell Curl',
        'type': 'weight',
        'muscleGroups': ['biceps'],
        'equipment': ['barbell'],
        'searchKeywords': ['barbell', 'curl', 'bicep']
      },
      {
        'id': 'hammer-curl',
        'name': 'Hammer Curl',
        'type': 'weight',
        'muscleGroups': ['biceps', 'forearms'],
        'equipment': ['dumbbells'],
        'searchKeywords': ['hammer', 'curl', 'bicep', 'dumbbell']
      },

      // Day 3: Shoulders & Traps
      {
        'id': 'overhead-press',
        'name': 'Overhead Press',
        'type': 'weight',
        'muscleGroups': ['shoulders', 'triceps'],
        'equipment': ['barbell'],
        'searchKeywords': ['overhead', 'press', 'shoulder', 'military']
      },
      {
        'id': 'dumbbell-lateral-raise',
        'name': 'Dumbbell Lateral Raise',
        'type': 'weight',
        'muscleGroups': ['shoulders'],
        'equipment': ['dumbbells'],
        'searchKeywords': ['lateral', 'raise', 'shoulder', 'dumbbell']
      },
      {
        'id': 'face-pulls',
        'name': 'Face Pulls',
        'type': 'weight',
        'muscleGroups': ['shoulders', 'traps'],
        'equipment': ['cable'],
        'searchKeywords': ['face', 'pull', 'cable', 'shoulder']
      },
      {
        'id': 'dumbbell-front-raise',
        'name': 'Dumbbell Front Raise',
        'type': 'weight',
        'muscleGroups': ['shoulders'],
        'equipment': ['dumbbells'],
        'searchKeywords': ['front', 'raise', 'shoulder', 'dumbbell']
      },
      {
        'id': 'barbell-shrugs',
        'name': 'Barbell Shrugs',
        'type': 'weight',
        'muscleGroups': ['traps'],
        'equipment': ['barbell'],
        'searchKeywords': ['shrug', 'shrugs', 'trap', 'barbell']
      },

      // Day 4: Legs
      {
        'id': 'squat',
        'name': 'Squat',
        'type': 'weight',
        'muscleGroups': ['quads', 'glutes', 'hamstrings'],
        'equipment': ['barbell', 'rack'],
        'searchKeywords': ['squat', 'leg', 'barbell']
      },
      {
        'id': 'romanian-deadlift',
        'name': 'Romanian Deadlift',
        'type': 'weight',
        'muscleGroups': ['hamstrings', 'glutes', 'back'],
        'equipment': ['barbell'],
        'searchKeywords': ['romanian', 'deadlift', 'rdl', 'hamstring']
      },
      {
        'id': 'leg-press',
        'name': 'Leg Press',
        'type': 'weight',
        'muscleGroups': ['quads', 'glutes'],
        'equipment': ['leg-press-machine'],
        'searchKeywords': ['leg', 'press', 'quad']
      },
      {
        'id': 'leg-curl',
        'name': 'Leg Curl',
        'type': 'weight',
        'muscleGroups': ['hamstrings'],
        'equipment': ['leg-curl-machine'],
        'searchKeywords': ['leg', 'curl', 'hamstring']
      },
      {
        'id': 'calf-raise',
        'name': 'Calf Raise',
        'type': 'weight',
        'muscleGroups': ['calves'],
        'equipment': ['calf-machine'],
        'searchKeywords': ['calf', 'raise', 'calves']
      },

      // Timer-based workouts (example)
      {
        'id': 'plank',
        'name': 'Plank',
        'type': 'timer',
        'muscleGroups': ['core', 'abs'],
        'equipment': ['bodyweight'],
        'searchKeywords': ['plank', 'core', 'abs']
      },
    ];

    for (final workout in globalWorkouts) {
      final muscleGroupsJson = (workout['muscleGroups'] as List).join(',');
      final equipmentJson = (workout['equipment'] as List).join(',');
      final searchKeywordsJson = (workout['searchKeywords'] as List).join(',');

      await _database.into(_database.globalWorkouts).insert(
        GlobalWorkoutsCompanion.insert(
          id: workout['id'] as String,
          name: workout['name'] as String,
          type: workout['type'] as String,
          muscleGroups: muscleGroupsJson,
          equipment: equipmentJson,
          searchKeywords: searchKeywordsJson,
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  /// Normalize workout name to a consistent ID (e.g., "Bench Press" -> "bench-press")
  String _normalizeWorkoutId(String workoutName) {
    return workoutName.toLowerCase().replaceAll(' ', '-');
  }

  String _getTargetReps(int weekNumber) {
    // Week cycle: week1=12, week2=9, week3=6, week4=3, then repeat
    final cycleWeek = ((weekNumber - 1) % 4) + 1;
    switch (cycleWeek) {
      case 1:
        return '12';
      case 2:
        return '9';
      case 3:
        return '6';
      case 4:
        return '3';
      default:
        return '12';
    }
  }

  /// Calculate weight based on base weight, week number, and phase progression
  /// Formula: phase(n+1)week(1) = phase(n)week(1)+5, phase(n)week(m) = phase(n)week(m-1)+5
  double _calculateWeight(double baseWeight, int weekNumber) {
    // Phase: 0 or 1 for 8 weeks (every 4 weeks = 1 phase)
    final phase = (weekNumber - 1) ~/ 4;
    // Week within current phase: 0, 1, 2, or 3
    final weekInPhase = (weekNumber - 1) % 4;

    // Add 5kg per phase and 5kg per week within the phase
    return baseWeight + (phase * 5) + (weekInPhase * 5);
  }

  // Day 1: Chest & Triceps
  List<Map<String, dynamic>> _getDay1Workouts() {
    return [
      {'name': 'Bench Press', 'notes': 'Focus on controlled eccentric', 'baseWeights': [10.0, 10.0, 10.0, 10.0]},
      {'name': 'Incline Dumbbell Press', 'notes': '30-45 degree angle', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Cable Flyes', 'notes': 'Squeeze at center', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Tricep Dips', 'notes': 'Lean forward for chest emphasis', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Tricep Pushdown', 'notes': 'Keep elbows stationary', 'baseWeights': [10.0, 10.0, 10.0]},
    ];
  }

  // Day 2: Back & Biceps
  List<Map<String, dynamic>> _getDay2Workouts() {
    return [
      {'name': 'Deadlift', 'notes': 'Keep back neutral', 'baseWeights': [10.0, 10.0, 10.0, 10.0]},
      {'name': 'Pull-ups', 'notes': 'Full range of motion', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Barbell Row', 'notes': 'Pull to lower chest', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Lat Pulldown', 'notes': 'Wide grip', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Barbell Curl', 'notes': 'No swinging', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Hammer Curl', 'notes': 'Alternating arms', 'baseWeights': [10.0, 10.0, 10.0]},
    ];
  }

  // Day 3: Shoulders & Traps
  List<Map<String, dynamic>> _getDay3Workouts() {
    return [
      {'name': 'Overhead Press', 'notes': 'Keep core tight', 'baseWeights': [10.0, 10.0, 10.0, 10.0]},
      {'name': 'Dumbbell Lateral Raise', 'notes': 'Slight bend in elbows', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Face Pulls', 'notes': 'Pull to face level', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Dumbbell Front Raise', 'notes': 'Alternating arms', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Barbell Shrugs', 'notes': 'Hold at top', 'baseWeights': [10.0, 10.0, 10.0]},
    ];
  }

  // Day 4: Legs
  List<Map<String, dynamic>> _getDay4Workouts() {
    return [
      {'name': 'Squat', 'notes': 'Full depth, knees out', 'baseWeights': [10.0, 10.0, 10.0, 10.0]},
      {'name': 'Romanian Deadlift', 'notes': 'Feel hamstring stretch', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Leg Press', 'notes': 'Feet shoulder width', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Leg Curl', 'notes': 'Control the negative', 'baseWeights': [10.0, 10.0, 10.0]},
      {'name': 'Calf Raise', 'notes': 'Full stretch and contraction', 'baseWeights': [10.0, 10.0, 10.0]},
    ];
  }

}
