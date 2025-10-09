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
  TextColumn get id => text()();
  TextColumn get dayId => text().references(Days, #id)();
  TextColumn get name => text()();
  IntColumn get order => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get defaultSets => integer()();

  @override
  Set<Column> get primaryKey => {id};
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
  TextColumn get workoutId => text()();
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
  TextColumn get workoutId => text()();
  DateTimeColumn get lastCompletedAt => dateTime()();
  IntColumn get totalSets => integer()();

  @override
  Set<Column> get primaryKey => {userId, workoutId};
}

// User-Specific Workout Alternatives
class WorkoutAlternatives extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get originalWorkoutId => text()();
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
  int get schemaVersion => 3;

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
