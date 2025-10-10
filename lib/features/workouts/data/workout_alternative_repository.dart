import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/models/workout_alternative.dart' as model;

class WorkoutAlternativeRepository {
  final AppDatabase _database;

  WorkoutAlternativeRepository(this._database);

  // Create a new workout alternative
  Future<void> createAlternative(model.WorkoutAlternative alternative) async {
    await _database.into(_database.workoutAlternatives).insert(
          WorkoutAlternativesCompanion.insert(
            id: alternative.id,
            userId: alternative.userId,
            globalWorkoutId: alternative.globalWorkoutId,
            name: alternative.name,
            createdAt: alternative.createdAt,
          ),
        );
  }

  // Get all alternatives for a specific workout (by globalWorkoutId)
  Future<List<model.WorkoutAlternative>> getAlternativesForWorkout(
    String userId,
    String globalWorkoutId,
  ) async {
    final query = _database.select(_database.workoutAlternatives)
      ..where((tbl) =>
          tbl.userId.equals(userId) &
          tbl.globalWorkoutId.equals(globalWorkoutId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);

    final results = await query.get();

    return results
        .map((row) => model.WorkoutAlternative(
              id: row.id,
              userId: row.userId,
              globalWorkoutId: row.globalWorkoutId,
              name: row.name,
              createdAt: row.createdAt,
            ))
        .toList();
  }

  // Get a specific alternative by ID
  Future<model.WorkoutAlternative?> getAlternativeById(String id) async {
    final query = _database.select(_database.workoutAlternatives)
      ..where((tbl) => tbl.id.equals(id));

    final result = await query.getSingleOrNull();

    if (result == null) return null;

    return model.WorkoutAlternative(
      id: result.id,
      userId: result.userId,
      globalWorkoutId: result.globalWorkoutId,
      name: result.name,
      createdAt: result.createdAt,
    );
  }

  // Delete an alternative
  Future<void> deleteAlternative(String id) async {
    await (_database.delete(_database.workoutAlternatives)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  // Update alternative name
  Future<void> updateAlternativeName(String id, String newName) async {
    await (_database.update(_database.workoutAlternatives)
          ..where((tbl) => tbl.id.equals(id)))
        .write(WorkoutAlternativesCompanion(
      name: Value(newName),
    ));
  }
}
