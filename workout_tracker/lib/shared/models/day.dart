import 'package:freezed_annotation/freezed_annotation.dart';

part 'day.freezed.dart';
part 'day.g.dart';

@freezed
class Day with _$Day {
  const factory Day({
    required String id,
    required String weekId,
    required int dayNumber,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Day;

  factory Day.fromJson(Map<String, dynamic> json) => _$DayFromJson(json);
}
