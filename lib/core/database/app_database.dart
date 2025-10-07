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
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workout_tracker.sqlite'));
    return NativeDatabase(file);
  });
}
