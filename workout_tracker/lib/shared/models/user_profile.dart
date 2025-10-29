import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String userId,
    required String displayName,
    String? email,
    String? currentPlanId,
    int? currentWeekNumber,
    int? currentDayNumber,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? syncLastTemplateSync,  // Timestamp of last template sync from Firestore
    DateTime? syncLastProgressSync,  // Timestamp of last progress sync with Firestore
    String? gymCardPath,  // Local file path to gym membership card image
    DateTime? gymCardUpdatedAt,  // Timestamp when gym card was last updated
    @Default(45) int defaultRestTimerSeconds,  // User's preferred rest timer duration (device-only setting)
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
