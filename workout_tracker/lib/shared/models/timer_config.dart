import 'package:freezed_annotation/freezed_annotation.dart';

part 'timer_config.freezed.dart';
part 'timer_config.g.dart';

@freezed
class TimerConfig with _$TimerConfig {
  const factory TimerConfig({
    required String id,
    String? workoutId, // null means global default
    required int durationSeconds,
    required bool isActive,
  }) = _TimerConfig;

  factory TimerConfig.fromJson(Map<String, dynamic> json) =>
      _$TimerConfigFromJson(json);
}
