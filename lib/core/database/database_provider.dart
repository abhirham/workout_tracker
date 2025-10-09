import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import '../../features/workouts/data/workout_alternative_repository.dart';

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
