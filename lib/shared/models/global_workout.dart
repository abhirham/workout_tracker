import 'package:freezed_annotation/freezed_annotation.dart';

part 'global_workout.freezed.dart';
part 'global_workout.g.dart';

enum WorkoutType {
  @JsonValue('weight')
  weight,
  @JsonValue('timer')
  timer,
}

@freezed
class GlobalWorkout with _$GlobalWorkout {
  const factory GlobalWorkout({
    required String id,
    required String name,
    required WorkoutType type,
    required DateTime createdAt,
  }) = _GlobalWorkout;

  factory GlobalWorkout.fromJson(Map<String, dynamic> json) =>
      _$GlobalWorkoutFromJson(json);
}
