import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/database_provider.dart';
import '../../../shared/models/global_workout.dart';

part 'global_workout_repository.g.dart';

@riverpod
GlobalWorkoutRepository globalWorkoutRepository(GlobalWorkoutRepositoryRef ref) {
  final database = ref.watch(databaseProvider);
  return GlobalWorkoutRepository(database);
}

class GlobalWorkoutRepository {
  final db.AppDatabase _database;

  GlobalWorkoutRepository(this._database);

  /// Get all global workouts
  Future<List<GlobalWorkout>> getAllGlobalWorkouts() async {
    final results = await _database.select(_database.globalWorkouts).get();
    return results.map((row) => _globalWorkoutFromRow(row)).toList();
  }

  /// Get a global workout by ID
  Future<GlobalWorkout?> getGlobalWorkoutById(String id) async {
    final result = await (_database.select(_database.globalWorkouts)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();

    if (result == null) return null;
    return _globalWorkoutFromRow(result);
  }

  /// Get global workouts by type
  Future<List<GlobalWorkout>> getGlobalWorkoutsByType(WorkoutType type) async {
    final typeString = type == WorkoutType.weight ? 'weight' : 'timer';
    final results = await (_database.select(_database.globalWorkouts)
          ..where((tbl) => tbl.type.equals(typeString)))
        .get();
    return results.map((row) => _globalWorkoutFromRow(row)).toList();
  }

  /// Create a new global workout
  Future<void> createGlobalWorkout(GlobalWorkout workout) async {
    await _database.into(_database.globalWorkouts).insert(
          db.GlobalWorkoutsCompanion.insert(
            id: workout.id,
            name: workout.name,
            type: workout.type == WorkoutType.weight ? 'weight' : 'timer',
            muscleGroups: workout.muscleGroups.join(','),
            equipment: workout.equipment.join(','),
            searchKeywords: workout.searchKeywords.join(','),
            isActive: Value(workout.isActive),
            createdAt: workout.createdAt,
            updatedAt: workout.updatedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Update a global workout
  Future<void> updateGlobalWorkout(GlobalWorkout workout) async {
    await (_database.update(_database.globalWorkouts)
          ..where((tbl) => tbl.id.equals(workout.id)))
        .write(
      db.GlobalWorkoutsCompanion(
        name: Value(workout.name),
        type: Value(workout.type == WorkoutType.weight ? 'weight' : 'timer'),
        muscleGroups: Value(workout.muscleGroups.join(',')),
        equipment: Value(workout.equipment.join(',')),
        searchKeywords: Value(workout.searchKeywords.join(',')),
        isActive: Value(workout.isActive),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a global workout
  Future<void> deleteGlobalWorkout(String id) async {
    await (_database.delete(_database.globalWorkouts)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Convert database row to GlobalWorkout model
  GlobalWorkout _globalWorkoutFromRow(db.GlobalWorkout row) {
    // Parse comma-separated strings back to lists
    final muscleGroups = row.muscleGroups.split(',').where((s) => s.isNotEmpty).toList();
    final equipment = row.equipment.split(',').where((s) => s.isNotEmpty).toList();
    final searchKeywords = row.searchKeywords.split(',').where((s) => s.isNotEmpty).toList();

    return GlobalWorkout(
      id: row.id,
      name: row.name,
      type: row.type == 'weight' ? WorkoutType.weight : WorkoutType.timer,
      muscleGroups: muscleGroups,
      equipment: equipment,
      searchKeywords: searchKeywords,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
