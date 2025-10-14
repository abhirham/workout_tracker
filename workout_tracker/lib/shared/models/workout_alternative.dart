import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_alternative.freezed.dart';
part 'workout_alternative.g.dart';

@freezed
class WorkoutAlternative with _$WorkoutAlternative {
  const factory WorkoutAlternative({
    required String id,
    required String userId,
    required String globalWorkoutId,  // Links to GlobalWorkouts.id - consistent across all weeks
    required String name,
    required DateTime createdAt,
  }) = _WorkoutAlternative;

  factory WorkoutAlternative.fromJson(Map<String, dynamic> json) =>
      _$WorkoutAlternativeFromJson(json);
}
