import 'package:freezed_annotation/freezed_annotation.dart';

part 'completed_set.freezed.dart';
part 'completed_set.g.dart';

@freezed
class CompletedSet with _$CompletedSet {
  const factory CompletedSet({
    required String id,
    required String userId,
    required String weekId,  // Part of composite key for tracking progress
    required String workoutId,  // References Workouts.id (consistent across weeks)
    required int setNumber,
    required double weight,
    required int reps,
    required DateTime completedAt,
    String? workoutAlternativeId,
  }) = _CompletedSet;

  factory CompletedSet.fromJson(Map<String, dynamic> json) =>
      _$CompletedSetFromJson(json);
}
