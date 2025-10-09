import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import 'database_seeder.dart';
import '../../features/workouts/data/workout_alternative_repository.dart';
import '../../features/workouts/data/completed_set_repository.dart';
import '../../features/workouts/data/workout_template_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    database.close();
  });
  return database;
});

final workoutAlternativeRepositoryProvider = Provider<WorkoutAlternativeRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return WorkoutAlternativeRepository(database);
});

final completedSetRepositoryProvider = Provider<CompletedSetRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return CompletedSetRepository(database);
});

final workoutTemplateRepositoryProvider = Provider<WorkoutTemplateRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return WorkoutTemplateRepository(database);
});

final databaseSeederProvider = Provider<DatabaseSeeder>((ref) {
  final database = ref.watch(databaseProvider);
  return DatabaseSeeder(database);
});
