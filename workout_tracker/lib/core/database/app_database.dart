import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Global Workouts Library
class GlobalWorkouts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();  // 'weight' or 'timer'
  TextColumn get muscleGroups => text()();  // JSON array of muscle groups
  TextColumn get equipment => text()();  // JSON array of equipment
  TextColumn get searchKeywords => text()();  // JSON array of lowercase keywords for autocomplete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();  // Soft delete flag
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

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
  TextColumn get id => text()();  // Primary key for this workout instance
  TextColumn get planId => text().references(WorkoutPlans, #id)();  // Reference to workout plan
  TextColumn get globalWorkoutId => text().references(GlobalWorkouts, #id)();  // Reference to global workout
  TextColumn get dayId => text().references(Days, #id)();
  TextColumn get name => text()();  // Display name (e.g., "Bench Press")
  IntColumn get order => integer()();
  TextColumn get notes => text().nullable()();
  TextColumn get baseWeights => text().nullable()();  // JSON array for progressive overload base (null for timer workouts)
  TextColumn get targetReps => text().nullable()();  // Target reps set by admin per workout (e.g., "12", "8-10", "AMRAP") (null for timer workouts)
  IntColumn get restTimerSeconds => integer().nullable()();  // Rest between sets for weight workouts (null for timer)
  IntColumn get workoutDurationSeconds => integer().nullable()();  // Duration for timer workouts (null for weight)
  TextColumn get alternativeWorkouts => text().nullable()();  // JSON array of alternative globalWorkoutIds
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};  // Single primary key for foreign key references
}

class SetTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get workoutId => text().references(Workouts, #id)();
  IntColumn get setNumber => integer()();
  IntColumn get suggestedReps => integer().nullable()();
  RealColumn get suggestedWeight => real().nullable()();
  IntColumn get suggestedDuration => integer().nullable()();  // Duration in seconds for timer-based workouts

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
  TextColumn get email => text().nullable()();
  TextColumn get currentPlanId => text().nullable()();
  IntColumn get currentWeekNumber => integer().nullable()();
  IntColumn get currentDayNumber => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncLastTemplateSync => dateTime().nullable()();  // Timestamp of last template sync from Firestore
  DateTimeColumn get syncLastProgressSync => dateTime().nullable()();  // Timestamp of last progress sync with Firestore

  @override
  Set<Column> get primaryKey => {userId};
}

class CompletedSets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get planId => text()();  // Part of composite key
  TextColumn get weekId => text()();  // Part of composite key
  TextColumn get dayId => text()();  // Part of composite key
  TextColumn get workoutId => text()();  // References Workouts.id - Part of composite key
  TextColumn get workoutName => text()();  // Actual exercise name performed (for Firestore sync compatibility)
  IntColumn get setNumber => integer()();
  RealColumn get weight => real().nullable()();  // Nullable for timer-based workouts
  IntColumn get reps => integer().nullable()();  // Nullable for timer-based workouts
  IntColumn get duration => integer().nullable()();  // Duration in seconds for timer-based workouts
  DateTimeColumn get completedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();  // Timestamp when synced to Firestore
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
  TextColumn get globalWorkoutId => text().references(GlobalWorkouts, #id)();  // Links to global workout
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
  GlobalWorkouts,
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
  int get schemaVersion => 11;

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
        if (from < 7) {
          // Major schema change: introduce global workouts, update workouts table structure
          // Add timer-based workouts support, update composite keys

          // Drop and recreate all tables with new schema
          await customStatement('DROP TABLE IF EXISTS set_templates');
          await customStatement('DROP TABLE IF EXISTS timer_configs');
          await customStatement('DROP TABLE IF EXISTS completed_sets');
          await customStatement('DROP TABLE IF EXISTS workout_progress');
          await customStatement('DROP TABLE IF EXISTS workout_alternatives');
          await customStatement('DROP TABLE IF EXISTS workouts');
          await customStatement('DROP TABLE IF EXISTS days');
          await customStatement('DROP TABLE IF EXISTS weeks');
          await customStatement('DROP TABLE IF EXISTS workout_plans');

          // Create new global_workouts table
          await m.createTable(globalWorkouts);

          // Recreate all tables with updated schema
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
        if (from < 8) {
          // Major schema change: expand global workouts with metadata, move workout config from templates to workouts
          // Add Firestore sync fields to completed sets and user profiles

          // Drop and recreate all tables with new schema (safer than complex column additions)
          await customStatement('DROP TABLE IF EXISTS set_templates');
          await customStatement('DROP TABLE IF EXISTS timer_configs');
          await customStatement('DROP TABLE IF EXISTS completed_sets');
          await customStatement('DROP TABLE IF EXISTS workout_progress');
          await customStatement('DROP TABLE IF EXISTS workout_alternatives');
          await customStatement('DROP TABLE IF EXISTS workouts');
          await customStatement('DROP TABLE IF EXISTS days');
          await customStatement('DROP TABLE IF EXISTS weeks');
          await customStatement('DROP TABLE IF EXISTS workout_plans');
          await customStatement('DROP TABLE IF EXISTS global_workouts');
          await customStatement('DROP TABLE IF EXISTS user_profiles');

          // Recreate all tables with schema v8
          await m.createTable(globalWorkouts);
          await m.createTable(workoutPlans);
          await m.createTable(weeks);
          await m.createTable(days);
          await m.createTable(workouts);
          await m.createTable(setTemplates);
          await m.createTable(timerConfigs);
          await m.createTable(userProfiles);
          await m.createTable(completedSets);
          await m.createTable(workoutProgressTable);
          await m.createTable(workoutAlternatives);
        }
        if (from < 9) {
          // Clean slate for Google Sign-In migration
          // Clear all testing data with temp_user_id
          // Keep global_workouts structure (will sync from Firestore)
          // Keep user_profiles structure but clear data

          // Use DELETE with IF EXISTS check (SQLite doesn't support IF EXISTS for DELETE)
          // So we'll drop and recreate tables instead
          await customStatement('DROP TABLE IF EXISTS completed_sets');
          await customStatement('DROP TABLE IF EXISTS workout_progress');
          await customStatement('DROP TABLE IF EXISTS workout_alternatives');
          await customStatement('DROP TABLE IF EXISTS set_templates');
          await customStatement('DROP TABLE IF EXISTS timer_configs');
          await customStatement('DROP TABLE IF EXISTS workouts');
          await customStatement('DROP TABLE IF EXISTS days');
          await customStatement('DROP TABLE IF EXISTS weeks');
          await customStatement('DROP TABLE IF EXISTS workout_plans');
          await customStatement('DROP TABLE IF EXISTS user_profiles');
          await customStatement('DROP TABLE IF EXISTS sync_queue');

          // Recreate all tables with fresh schema
          await m.createTable(workoutPlans);
          await m.createTable(weeks);
          await m.createTable(days);
          await m.createTable(workouts);
          await m.createTable(setTemplates);
          await m.createTable(timerConfigs);
          await m.createTable(userProfiles);
          await m.createTable(completedSets);
          await m.createTable(workoutProgressTable);
          await m.createTable(workoutAlternatives);
          await m.createTable(syncQueue);

          // Note: global_workouts data will be re-seeded or synced from Firestore
        }
        if (from < 10) {
          // One-time migration: Clear ALL local data to sync with Firestore
          // This is a fresh start - all data will come from Firestore after this
          await customStatement('DELETE FROM completed_sets');
          await customStatement('DELETE FROM workout_progress');
          await customStatement('DELETE FROM workout_alternatives');
          await customStatement('DELETE FROM set_templates');
          await customStatement('DELETE FROM timer_configs');
          await customStatement('DELETE FROM workouts');
          await customStatement('DELETE FROM days');
          await customStatement('DELETE FROM weeks');
          await customStatement('DELETE FROM workout_plans');
          await customStatement('DELETE FROM global_workouts');
          await customStatement('DELETE FROM user_profiles');
          await customStatement('DELETE FROM sync_queue');

          // Database structure remains intact, but all data is cleared
          // Initial sync from Firestore will populate everything
        }
        if (from < 11) {
          // Schema change: targetReps column type changed from INTEGER to TEXT
          // This allows flexible rep ranges like "12", "8-10", "AMRAP", etc.
          // Clear all template data to allow re-sync from Firestore with new schema
          await customStatement('DELETE FROM set_templates');
          await customStatement('DELETE FROM timer_configs');
          await customStatement('DELETE FROM workouts');
          await customStatement('DELETE FROM days');
          await customStatement('DELETE FROM weeks');
          await customStatement('DELETE FROM workout_plans');
          await customStatement('DELETE FROM global_workouts');
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
