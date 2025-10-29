import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/user_service.dart';
import '../../data/user_preferences_repository.dart';

/// Bottom sheet for configuring rest timer duration preference
class RestTimerSettingsBottomSheet extends ConsumerStatefulWidget {
  const RestTimerSettingsBottomSheet({super.key});

  @override
  ConsumerState<RestTimerSettingsBottomSheet> createState() =>
      _RestTimerSettingsBottomSheetState();
}

class _RestTimerSettingsBottomSheetState
    extends ConsumerState<RestTimerSettingsBottomSheet> {
  // Preset duration options in seconds
  static const List<int> _presetDurations = [15, 30, 45, 60, 90, 120];

  // Labels for preset durations
  static const Map<int, String> _durationLabels = {
    15: '15s',
    30: '30s',
    45: '45s (Default)',
    60: '1 min',
    90: '1.5 min',
    120: '2 min',
  };

  int? _selectedDuration;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentDuration();
  }

  Future<void> _loadCurrentDuration() async {
    final userService = ref.read(userServiceProvider);
    final userId = userService.getCurrentUserIdOrThrow();
    final repository = ref.read(userPreferencesRepositoryProvider);

    final duration = await repository.getDefaultRestTimer(userId);

    if (mounted) {
      setState(() {
        _selectedDuration = duration;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDuration(int duration) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final userService = ref.read(userServiceProvider);
      final userId = userService.getCurrentUserIdOrThrow();
      final repository = ref.read(userPreferencesRepositoryProvider);

      await repository.updateDefaultRestTimer(userId, duration);

      if (mounted) {
        setState(() {
          _selectedDuration = duration;
          _isSaving = false;
        });

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rest timer set to ${_durationLabels[duration]}'),
            duration: const Duration(seconds: 2),
          ),
        );

        // Close the bottom sheet after a brief delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Rest Timer Duration',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how long to rest between sets',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),

          // Loading state
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Duration options grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _presetDurations.map((duration) {
                final isSelected = _selectedDuration == duration;
                return ChoiceChip(
                  label: Text(_durationLabels[duration] ?? '${duration}s'),
                  selected: isSelected,
                  onSelected: _isSaving
                      ? null
                      : (selected) {
                          if (selected) {
                            _saveDuration(duration);
                          }
                        },
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Saving indicator
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Saving...'),
                    ],
                  ),
                ),
              ),
          ],

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Helper function to show the rest timer settings bottom sheet
Future<void> showRestTimerSettings(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const RestTimerSettingsBottomSheet(),
  );
}
