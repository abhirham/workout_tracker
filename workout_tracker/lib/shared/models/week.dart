import 'package:freezed_annotation/freezed_annotation.dart';

part 'week.freezed.dart';
part 'week.g.dart';

@freezed
class Week with _$Week {
  const factory Week({
    required String id,
    required String planId,
    required int weekNumber,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Week;

  factory Week.fromJson(Map<String, dynamic> json) => _$WeekFromJson(json);
}
