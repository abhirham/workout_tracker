import 'package:freezed_annotation/freezed_annotation.dart';

part 'completed_set.freezed.dart';
part 'completed_set.g.dart';

@freezed
class CompletedSet with _$CompletedSet {
  const factory CompletedSet({
    required String id,
    required String userId,
    required String planId,  // Part of composite key for tracking progress
    required String weekId,  // Part of composite key for tracking progress
    required String dayId,  // Part of composite key for tracking progress
    required String workoutId,  // References Workouts.id - Part of composite key
    required int setNumber,
    double? weight,  // Nullable for timer-based workouts
    int? reps,  // Nullable for timer-based workouts
    int? duration,  // Duration in seconds for timer-based workouts
    required DateTime completedAt,
    String? workoutAlternativeId,
  }) = _CompletedSet;

  factory CompletedSet.fromJson(Map<String, dynamic> json) =>
      _$CompletedSetFromJson(json);
}
