import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/models/completed_set.dart' as model;

class CompletedSetRepository {
  final AppDatabase _database;

  CompletedSetRepository(this._database);

  // Save a completed set
  Future<void> saveCompletedSet(model.CompletedSet completedSet) async {
    await _database.into(_database.completedSets).insert(
          CompletedSetsCompanion.insert(
            id: completedSet.id,
            userId: completedSet.userId,
            weekId: completedSet.weekId,
            workoutId: completedSet.workoutId,
            setNumber: completedSet.setNumber,
            weight: completedSet.weight,
            reps: completedSet.reps,
            completedAt: completedSet.completedAt,
            workoutAlternativeId: Value(completedSet.workoutAlternativeId),
          ),
        );
  }

  // Get all completed sets for a specific workout in a specific week
  Future<List<model.CompletedSet>> getCompletedSetsForWorkout(
    String userId,
    String weekId,
    String workoutId, {
    String? alternativeId,
  }) async {
    final query = _database.select(_database.completedSets)
      ..where((tbl) =>
          tbl.userId.equals(userId) &
          tbl.weekId.equals(weekId) &
          tbl.workoutId.equals(workoutId) &
          (alternativeId != null
              ? tbl.workoutAlternativeId.equals(alternativeId)
              : tbl.workoutAlternativeId.isNull()))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.completedAt)]);

    final results = await query.get();

    return results
        .map((row) => model.CompletedSet(
              id: row.id,
              userId: row.userId,
              weekId: row.weekId,
              workoutId: row.workoutId,
              setNumber: row.setNumber,
              weight: row.weight,
              reps: row.reps,
              completedAt: row.completedAt,
              workoutAlternativeId: row.workoutAlternativeId,
            ))
        .toList();
  }

  // Get the most recent completed set for a specific set number in a specific week
  Future<model.CompletedSet?> getLastCompletedSet(
    String userId,
    String weekId,
    String workoutId,
    int setNumber, {
    String? alternativeId,
  }) async {
    final query = _database.select(_database.completedSets)
      ..where((tbl) =>
          tbl.userId.equals(userId) &
          tbl.weekId.equals(weekId) &
          tbl.workoutId.equals(workoutId) &
          tbl.setNumber.equals(setNumber) &
          (alternativeId != null
              ? tbl.workoutAlternativeId.equals(alternativeId)
              : tbl.workoutAlternativeId.isNull()))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.completedAt)])
      ..limit(1);

    final result = await query.getSingleOrNull();

    if (result == null) return null;

    return model.CompletedSet(
      id: result.id,
      userId: result.userId,
      weekId: result.weekId,
      workoutId: result.workoutId,
      setNumber: result.setNumber,
      weight: result.weight,
      reps: result.reps,
      completedAt: result.completedAt,
      workoutAlternativeId: result.workoutAlternativeId,
    );
  }

  // Delete all completed sets for a workout in a specific week (useful when deleting alternative)
  Future<void> deleteCompletedSetsForWorkout(
    String userId,
    String weekId,
    String workoutId, {
    String? alternativeId,
  }) async {
    await (_database.delete(_database.completedSets)
          ..where((tbl) =>
              tbl.userId.equals(userId) &
              tbl.weekId.equals(weekId) &
              tbl.workoutId.equals(workoutId) &
              (alternativeId != null
                  ? tbl.workoutAlternativeId.equals(alternativeId)
                  : tbl.workoutAlternativeId.isNull())))
        .go();
  }
}
