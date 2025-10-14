import 'package:drift/drift.dart';
import 'package:workout_tracker/core/database/app_database.dart';

class WeekRepository {
  final AppDatabase _database;

  WeekRepository(this._database);

  /// Get all weeks for a specific plan
  Future<List<Week>> getWeeksForPlan(String planId) async {
    return await (_database.select(_database.weeks)
          ..where((tbl) => tbl.planId.equals(planId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.weekNumber)]))
        .get();
  }

  /// Get a specific week by ID
  Future<Week?> getWeekById(String weekId) async {
    return await (_database.select(_database.weeks)
          ..where((tbl) => tbl.id.equals(weekId)))
        .getSingleOrNull();
  }

  /// Count days for a specific week
  Future<int> getDayCountForWeek(String weekId) async {
    final count = await (_database.select(_database.days)
          ..where((tbl) => tbl.weekId.equals(weekId)))
        .get();
    return count.length;
  }
}
