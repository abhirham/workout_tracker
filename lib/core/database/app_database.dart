import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Shared Template Tables
class WorkoutPlans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Weeks extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(WorkoutPlans, #id)();
  IntColumn get weekNumber => integer()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Days extends Table {
  TextColumn get id => text()();
  TextColumn get weekId => text().references(Weeks, #id)();
  IntColumn get dayNumber => integer()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Workouts extends Table {
  TextColumn get id => text()();  // Composite ID: dayId + workoutName (e.g., "week1_day_1_bench-press")
  TextColumn get dayId => text().references(Days, #id)();
  TextColumn get workoutName => text()();  // Base workout name (e.g., "bench-press") - consistent across weeks
  TextColumn get name => text()();  // Display name (e.g., "Bench Press")
  IntColumn get order => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get defaultSets => integer()();

  @override
  Set<Column> get primaryKey => {id};  // Single primary key for foreign key references
}

class SetTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text().references(Workouts, #id)();
  IntColumn get setNumber => integer()();
  IntColumn get suggestedReps => integer().nullable()();
  RealColumn get suggestedWeight => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class TimerConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text().nullable()();
  IntColumn get durationSeconds => integer()();
  BoolColumn get isActive => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

// User Progress Tables
class UserProfiles extends Table {
  TextColumn get userId => text()();
  TextColumn get displayName => text()();
  TextColumn get currentPlanId => text().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

class CompletedSets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get weekId => text()();  // Part of composite key
  TextColumn get workoutId => text()();  // References Workouts.id
  IntColumn get setNumber => integer()();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get workoutAlternativeId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutProgressTable extends Table {
  TextColumn get userId => text()();
  TextColumn get weekId => text()();  // Part of composite key
  TextColumn get workoutId => text()();  // References Workouts.id
  DateTimeColumn get lastCompletedAt => dateTime()();
  IntColumn get totalSets => integer()();

  @override
  Set<Column> get primaryKey => {userId, weekId, workoutId};  // Composite key for tracking progress per week
}

// User-Specific Workout Alternatives
class WorkoutAlternatives extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get workoutName => text()();  // Links to Workouts.workoutName (e.g., "bench-press") - consistent across weeks
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// Sync Management
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // 'create', 'update', 'delete'
  TextColumn get data => text()(); // JSON serialized data
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  WorkoutPlans,
  Weeks,
  Days,
  Workouts,
  SetTemplates,
  TimerConfigs,
  UserProfiles,
  CompletedSets,
  WorkoutProgressTable,
  WorkoutAlternatives,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add workoutAlternativeId column to CompletedSets
          await m.addColumn(completedSets, completedSets.workoutAlternativeId);
          // Create WorkoutAlternatives table
          await m.createTable(workoutAlternatives);
        }
        if (from < 3) {
          // Clear all template data to allow re-seeding with new week-specific day IDs
          // Must delete in correct order due to foreign key constraints
          await customStatement('DELETE FROM set_templates');
          await customStatement('DELETE FROM timer_configs');
          await customStatement('DELETE FROM workouts');
          await customStatement('DELETE FROM days');
          await customStatement('DELETE FROM weeks');
          await customStatement('DELETE FROM workout_plans');
        }
        if (from < 4) {
          // Clear all template data to re-seed with fixed plan ID
          // Must delete in correct order due to foreign key constraints
          await customStatement('DELETE FROM set_templates');
          await customStatement('DELETE FROM timer_configs');
          await customStatement('DELETE FROM workouts');
          await customStatement('DELETE FROM days');
          await customStatement('DELETE FROM weeks');
          await customStatement('DELETE FROM workout_plans');
        }
        if (from < 5) {
          // Add baseWorkoutName column to Workouts table with a default value
          await customStatement(
            'ALTER TABLE workouts ADD COLUMN base_workout_name TEXT NOT NULL DEFAULT ""',
          );

          // Rename originalWorkoutId to baseWorkoutName in WorkoutAlternatives
          // SQLite doesn't support RENAME COLUMN in older versions, so we'll recreate the table
          await customStatement('DROP TABLE IF EXISTS workout_alternatives_old');
          await customStatement('ALTER TABLE workout_alternatives RENAME TO workout_alternatives_old');
          await customStatement('''
            CREATE TABLE workout_alternatives (
              id TEXT NOT NULL PRIMARY KEY,
              user_id TEXT NOT NULL,
              base_workout_name TEXT NOT NULL,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          // Copy data from old table, using original_workout_id as base_workout_name temporarily
          // (Users will need to recreate their alternatives with the new structure)
          await customStatement('DROP TABLE workout_alternatives_old');

          // Clear all template data to re-seed with baseWorkoutName
          await customStatement('DELETE FROM set_templates');
          await customStatement('DELETE FROM timer_configs');
          await customStatement('DELETE FROM workouts');
          await customStatement('DELETE FROM days');
          await customStatement('DELETE FROM weeks');
          await customStatement('DELETE FROM workout_plans');
        }
        if (from < 6) {
          // Major schema change: workouts now have consistent IDs across weeks
          // Progress tracking uses composite weekId-workoutId

          // Drop and recreate tables with new schema (safer than trying to migrate)
          await customStatement('DROP TABLE IF EXISTS set_templates');
          await customStatement('DROP TABLE IF EXISTS timer_configs');
          await customStatement('DROP TABLE IF EXISTS completed_sets');
          await customStatement('DROP TABLE IF EXISTS workout_progress');
          await customStatement('DROP TABLE IF EXISTS workout_alternatives');
          await customStatement('DROP TABLE IF EXISTS workouts');
          await customStatement('DROP TABLE IF EXISTS days');
          await customStatement('DROP TABLE IF EXISTS weeks');
          await customStatement('DROP TABLE IF EXISTS workout_plans');

          // Recreate all tables with new schema
          await m.createTable(workoutPlans);
          await m.createTable(weeks);
          await m.createTable(days);
          await m.createTable(workouts);
          await m.createTable(setTemplates);
          await m.createTable(timerConfigs);
          await m.createTable(completedSets);
          await m.createTable(workoutProgressTable);
          await m.createTable(workoutAlternatives);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workout_tracker.sqlite'));
    return NativeDatabase(file);
  });
}
