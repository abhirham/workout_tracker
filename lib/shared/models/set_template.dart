import 'package:freezed_annotation/freezed_annotation.dart';

part 'set_template.freezed.dart';
part 'set_template.g.dart';

@freezed
class SetTemplate with _$SetTemplate {
  const factory SetTemplate({
    required String id,
    required String workoutId,
    required int setNumber,
    int? suggestedReps,
    double? suggestedWeight,
    int? suggestedDuration,  // Duration in seconds for timer-based workouts
  }) = _SetTemplate;

  factory SetTemplate.fromJson(Map<String, dynamic> json) =>
      _$SetTemplateFromJson(json);
}
