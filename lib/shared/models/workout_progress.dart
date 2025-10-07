import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_progress.freezed.dart';
part 'workout_progress.g.dart';

@freezed
class WorkoutProgress with _$WorkoutProgress {
  const factory WorkoutProgress({
    required String userId,
    required String workoutId,
    required DateTime lastCompletedAt,
    required int totalSets,
  }) = _WorkoutProgress;

  factory WorkoutProgress.fromJson(Map<String, dynamic> json) =>
      _$WorkoutProgressFromJson(json);
}
