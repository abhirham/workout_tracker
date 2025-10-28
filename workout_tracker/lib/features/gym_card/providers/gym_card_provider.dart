import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workout_tracker/core/services/user_service.dart';
import 'package:workout_tracker/features/gym_card/data/gym_card_repository.dart';

part 'gym_card_provider.g.dart';

/// Provider for gym card state management
@riverpod
class GymCard extends _$GymCard {
  @override
  Future<File?> build() async {
    final repository = ref.read(gymCardRepositoryProvider);
    final userId = ref.read(userServiceProvider).getCurrentUserIdOrThrow();

    // Load the gym card file for the current user
    return await repository.getGymCardFile(userId);
  }

  /// Upload a new gym card image
  Future<void> uploadImage(File imageFile) async {
    // Set loading state
    state = const AsyncLoading();

    try {
      final repository = ref.read(gymCardRepositoryProvider);
      final userId = ref.read(userServiceProvider).getCurrentUserIdOrThrow();

      // Save the image
      await repository.saveGymCard(userId, imageFile);

      // Fetch the newly saved file and update state
      final savedFile = await repository.getGymCardFile(userId);
      state = AsyncData(savedFile);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  /// Delete the current gym card
  Future<void> deleteCard() async {
    // Set loading state
    state = const AsyncLoading();

    try {
      final repository = ref.read(gymCardRepositoryProvider);
      final userId = ref.read(userServiceProvider).getCurrentUserIdOrThrow();

      // Delete the gym card
      await repository.deleteGymCard(userId);

      // Update state to null since card is deleted
      state = const AsyncData(null);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  /// Check if user has a gym card
  bool get hasCard {
    return state.value != null;
  }
}
