import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout.freezed.dart';
part 'workout.g.dart';

@freezed
class Workout with _$Workout {
  const factory Workout({
    required String id,
    required String planId,
    required String globalWorkoutId,
    required String dayId,
    required String name,
    required int order,
    required int numSets,  // Number of sets for this workout
    String? notes,
    double? baseWeight,  // Base weight for progressive overload (null for timer workouts)
    String? targetReps,  // Target reps set by admin per workout (e.g., "12", "8-10", "AMRAP") (null for timer workouts)
    int? restTimerSeconds,  // Rest between sets for weight workouts (null for timer)
    int? workoutDurationSeconds,  // Duration for timer workouts (null for weight)
    List<String>? alternativeWorkouts,  // JSON array of alternative globalWorkoutIds
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Workout;

  factory Workout.fromJson(Map<String, dynamic> json) =>
      _$WorkoutFromJson(json);
}
