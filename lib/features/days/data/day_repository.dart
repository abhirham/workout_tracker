import 'package:drift/drift.dart';
import 'package:workout_tracker/core/database/app_database.dart';

class DayRepository {
  final AppDatabase _database;

  DayRepository(this._database);

  /// Get all days for a specific week
  Future<List<Day>> getDaysForWeek(String weekId) async {
    return await (_database.select(_database.days)
          ..where((tbl) => tbl.weekId.equals(weekId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]))
        .get();
  }

  /// Get a specific day by ID
  Future<Day?> getDayById(String dayId) async {
    return await (_database.select(_database.days)
          ..where((tbl) => tbl.id.equals(dayId)))
        .getSingleOrNull();
  }

  /// Count workouts for a specific day
  Future<int> getWorkoutCountForDay(String dayId) async {
    final count = await (_database.select(_database.workouts)
          ..where((tbl) => tbl.dayId.equals(dayId)))
        .get();
    return count.length;
  }
}
