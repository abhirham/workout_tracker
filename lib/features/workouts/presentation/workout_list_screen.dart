import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/models/workout_alternative.dart';

class WorkoutListScreen extends ConsumerStatefulWidget {
  final String planId;
  final String weekId;
  final String dayId;
  final String dayName;
  final int weekNumber;

  const WorkoutListScreen({
    super.key,
    required this.planId,
    required this.weekId,
    required this.dayId,
    required this.dayName,
    required this.weekNumber,
  });

  @override
  ConsumerState<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends ConsumerState<WorkoutListScreen> {
  // Calculate reps based on week number: week1=12, week2=9, week3=6, week4=3, then repeat
  int get targetRepsForWeek {
    final cycleWeek = ((widget.weekNumber - 1) % 4) + 1;
    switch (cycleWeek) {
      case 1:
        return 12;
      case 2:
        return 9;
      case 3:
        return 6;
      case 4:
        return 3;
      default:
        return 12;
    }
  }

  // TODO: Replace with actual data from repository
  List<Map<String, dynamic>> get mockWorkouts => [
        {
          'id': 'workout_1',
          'name': 'Bench Press',
          'notes': 'Focus on slow eccentric',
          'sets': [
            {
              'setNumber': 1,
              'suggestedReps': targetRepsForWeek,
              'suggestedWeight': 135.0,
              'actualReps': null,
              'actualWeight': null,
              'completed': false
            },
            {
              'setNumber': 2,
              'suggestedReps': targetRepsForWeek,
              'suggestedWeight': 155.0,
              'actualReps': null,
              'actualWeight': null,
              'completed': false
            },
            {
              'setNumber': 3,
              'suggestedReps': targetRepsForWeek,
              'suggestedWeight': 175.0,
              'actualReps': null,
              'actualWeight': null,
              'completed': false
            },
          ],
        },
        {
          'id': 'workout_2',
          'name': 'Overhead Press',
          'notes': null,
          'sets': [
            {
              'setNumber': 1,
              'suggestedReps': targetRepsForWeek,
              'suggestedWeight': 75.0,
              'actualReps': null,
              'actualWeight': null,
              'completed': false
            },
            {
              'setNumber': 2,
              'suggestedReps': targetRepsForWeek,
              'suggestedWeight': 85.0,
              'actualReps': null,
              'actualWeight': null,
              'completed': false
            },
            {
              'setNumber': 3,
              'suggestedReps': targetRepsForWeek,
              'suggestedWeight': 95.0,
              'actualReps': null,
              'actualWeight': null,
              'completed': false
            },
          ],
        },
        {
          'id': 'workout_3',
          'name': 'Incline Dumbbell Press',
          'notes': '30 degree angle',
          'sets': [
            {
              'setNumber': 1,
              'suggestedReps': targetRepsForWeek,
              'suggestedWeight': 60.0,
              'actualReps': null,
              'actualWeight': null,
              'completed': false
            },
            {
              'setNumber': 2,
              'suggestedReps': targetRepsForWeek,
              'suggestedWeight': 70.0,
              'actualReps': null,
              'actualWeight': null,
              'completed': false
            },
          ],
        },
      ];

  int currentWorkoutIndex = 0;
  int? currentSetIndex; // Track which set is currently editable
  int? timerSeconds; // Countdown timer
  bool isTimerRunning = false;
  Timer? _timer;
  String? selectedAlternativeId; // null = original workout
  String? selectedAlternativeName; // Name of selected alternative

  @override
  void initState() {
    super.initState();
    // Find the first uncompleted set, or default to 0
    final currentWorkout = mockWorkouts[currentWorkoutIndex];
    final sets = currentWorkout['sets'] as List;
    currentSetIndex = sets.indexWhere((set) => set['completed'] == false);
    if (currentSetIndex == -1) {
      currentSetIndex = 0; // All completed, reset to first
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      timerSeconds = 45;
      isTimerRunning = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (timerSeconds! > 0) {
          timerSeconds = timerSeconds! - 1;
        } else {
          timer.cancel();
          isTimerRunning = false;
          // Move to next set
          final currentWorkout = mockWorkouts[currentWorkoutIndex];
          final sets = currentWorkout['sets'] as List;
          if (currentSetIndex! < sets.length - 1) {
            currentSetIndex = currentSetIndex! + 1;
          }
          timerSeconds = null;
        }
      });
    });
  }

  void _saveSet(Map<String, dynamic> set, int setIndex) {
    setState(() {
      set['completed'] = true;

      // TODO: Save to database with workoutAlternativeId if alternative is selected
      // When implementing database save:
      // - Include selectedAlternativeId in CompletedSet model
      // - Use current workout ID (or alternative's originalWorkoutId)
      // - Save: workoutId, setNumber, actualWeight, actualReps, workoutAlternativeId, completedAt
      // Example:
      // final completedSet = CompletedSet(
      //   id: uuid.v4(),
      //   userId: userId,
      //   workoutId: currentWorkout['id'],
      //   setNumber: set['setNumber'],
      //   weight: set['actualWeight'],
      //   reps: set['actualReps'],
      //   workoutAlternativeId: selectedAlternativeId, // null if original workout
      //   completedAt: DateTime.now(),
      // );
      // await completedSetRepository.save(completedSet);

      // Only start timer if not the last set
      final currentWorkout = mockWorkouts[currentWorkoutIndex];
      final sets = currentWorkout['sets'] as List;
      if (setIndex < sets.length - 1) {
        _startTimer();
      } else {
        // Last set - move to next set index without timer
        currentSetIndex = setIndex + 1;
      }
    });
  }

  Future<void> _showAlternativesModal() async {
    final currentWorkout = mockWorkouts[currentWorkoutIndex];
    final originalWorkoutName = currentWorkout['name'] as String;
    final originalWorkoutId = currentWorkout['id'] as String;

    // Load alternatives from repository
    final repository = ref.read(workoutAlternativeRepositoryProvider);
    // TODO: Get actual userId from auth/profile
    const userId = 'temp_user_id'; // Placeholder until auth is implemented

    final alternatives = await repository.getAlternativesForWorkout(
      userId,
      originalWorkoutId,
    );

    if (!mounted) return;

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => _AlternativesBottomSheet(
        originalWorkoutId: originalWorkoutId,
        originalWorkoutName: originalWorkoutName,
        selectedAlternativeId: selectedAlternativeId,
        alternatives: alternatives,
        onAlternativeSelected: (String? altId, String? altName) {
          setState(() {
            selectedAlternativeId = altId;
            selectedAlternativeName = altName;
            // TODO: Reload progress for selected alternative
            // When implementing:
            // - Query CompletedSet WHERE workoutId = X AND workoutAlternativeId = altId
            // - If altId is null, query WHERE workoutId = X AND workoutAlternativeId IS NULL
            // - Update UI to show progress for selected alternative
            // - Reset currentSetIndex to first uncompleted set
          });
          Navigator.pop(context);
        },
        onCreateAlternative: (String name) async {
          // Create alternative in repository
          const uuid = Uuid();
          final newAlternative = WorkoutAlternative(
            id: uuid.v4(),
            userId: userId,
            originalWorkoutId: originalWorkoutId,
            name: name,
            createdAt: DateTime.now(),
          );

          await repository.createAlternative(newAlternative);

          // Auto-select the newly created alternative
          setState(() {
            selectedAlternativeId = newAlternative.id;
            selectedAlternativeName = newAlternative.name;
            // TODO: Reload progress for selected alternative
            // Since this is a new alternative, progress should be fresh (no completed sets)
            // Reset currentSetIndex to 0
          });

          if (!mounted) return;
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentWorkout = mockWorkouts[currentWorkoutIndex];
    final isLastWorkout = currentWorkoutIndex == mockWorkouts.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dayName),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${currentWorkoutIndex + 1}/${mockWorkouts.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isTimerRunning && timerSeconds != null)
            InkWell(
              onTap: () {
                // Skip timer
                _timer?.cancel();
                setState(() {
                  isTimerRunning = false;
                  timerSeconds = null;
                  // Move to next set
                  final currentWorkout = mockWorkouts[currentWorkoutIndex];
                  final sets = currentWorkout['sets'] as List;
                  if (currentSetIndex! < sets.length - 1) {
                    currentSetIndex = currentSetIndex! + 1;
                  }
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rest: ${timerSeconds}s',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(tap to skip)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildWorkoutCard(context, currentWorkout),
            ),
          ),
          _buildNavigationButtons(context, isLastWorkout),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, bool isLastWorkout) {
    // Get next exercise name if available
    String? nextExerciseName;
    if (!isLastWorkout && currentWorkoutIndex < mockWorkouts.length - 1) {
      nextExerciseName = mockWorkouts[currentWorkoutIndex + 1]['name'] as String;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (currentWorkoutIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          currentWorkoutIndex--;
                          // Reset to first uncompleted set for previous workout
                          final workout = mockWorkouts[currentWorkoutIndex];
                          final sets = workout['sets'] as List;
                          currentSetIndex =
                              sets.indexWhere((set) => set['completed'] == false);
                          if (currentSetIndex == -1) {
                            currentSetIndex = 0;
                          }
                          // Cancel any running timer
                          _timer?.cancel();
                          isTimerRunning = false;
                          timerSeconds = null;
                        });
                      },
                      child: const Text('Previous'),
                    ),
                  ),
                if (currentWorkoutIndex > 0) const SizedBox(width: 12),
                Expanded(
                  flex: currentWorkoutIndex > 0 ? 1 : 1,
                  child: FilledButton(
                    onPressed: isLastWorkout
                        ? () {
                            // TODO: Navigate back or show completion screen
                            Navigator.of(context).pop();
                          }
                        : () {
                            setState(() {
                              currentWorkoutIndex++;
                              // Reset to first uncompleted set for next workout
                              final workout = mockWorkouts[currentWorkoutIndex];
                              final sets = workout['sets'] as List;
                              currentSetIndex = sets
                                  .indexWhere((set) => set['completed'] == false);
                              if (currentSetIndex == -1) {
                                currentSetIndex = 0;
                              }
                              // Cancel any running timer
                              _timer?.cancel();
                              isTimerRunning = false;
                              timerSeconds = null;
                            });
                          },
                    child: Text(isLastWorkout ? 'Finish' : 'Next'),
                  ),
                ),
              ],
            ),
            if (nextExerciseName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Next: $nextExerciseName',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context, Map<String, dynamic> workout) {
    final sets = workout['sets'] as List;
    final completedSets = sets.where((s) => s['completed'] == true).length;
    final displayName = selectedAlternativeName ?? (workout['name'] as String);

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showAlternativesModal,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Alternatives'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                if (workout['notes'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    workout['notes'] as String,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: completedSets == sets.length
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$completedSets/${sets.length} sets',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...sets.asMap().entries.map((entry) {
            final index = entry.key;
            final set = entry.value;
            return _buildSetRow(context, workout, set, index);
          }),
        ],
      ),
    );
  }

  Widget _buildSetRow(
      BuildContext context,
      Map<String, dynamic> workout,
      Map<String, dynamic> set,
      int setIndex) {
    final isCurrentSet = currentSetIndex == setIndex;
    final isCompleted = set['completed'] as bool;
    final isEnabled = isCurrentSet && !isTimerRunning;

    // Get weight from previous set if it exists and current set has no value
    String getInitialWeight() {
      if (set['actualWeight'] != null) {
        return set['actualWeight'].toString();
      }

      // Look for previous set's weight
      if (setIndex > 0) {
        final sets = workout['sets'] as List;
        final previousSet = sets[setIndex - 1];
        if (previousSet['actualWeight'] != null) {
          return previousSet['actualWeight'].toString();
        }
      }

      // Fall back to suggested weight or empty
      return set['suggestedWeight']?.toString() ?? '';
    }

    final weightController = TextEditingController(
      text: getInitialWeight(),
    );

    // Reps are always the suggested reps (set by admin, constant for the week)
    final targetReps = set['suggestedReps'];
    final actualReps = set['actualReps'] ?? targetReps;
    final repsController = TextEditingController(
      text: actualReps?.toString() ?? '',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentSet && !isCompleted
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Set number
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Theme.of(context).colorScheme.primary
                      : isCurrentSet
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        )
                      : Text(
                          '${set['setNumber']}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isCurrentSet
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Weight input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight (lbs)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: weightController,
                      enabled: isEnabled,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 12,
                          right: 60,
                          top: 8,
                          bottom: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: set['suggestedWeight']?.toString(),
                        suffixIcon: isEnabled
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      final currentValue =
                                          double.tryParse(weightController.text) ??
                                              0;
                                      final newValue =
                                          (currentValue - 2.5).clamp(0, 9999);
                                      weightController.text =
                                          newValue.toStringAsFixed(1);
                                      set['actualWeight'] = newValue;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      final currentValue =
                                          double.tryParse(weightController.text) ??
                                              0;
                                      final newValue = currentValue + 5;
                                      weightController.text =
                                          newValue.toStringAsFixed(1);
                                      set['actualWeight'] = newValue;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        set['actualWeight'] = double.tryParse(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Reps input (actual reps completed, target shown above)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reps (Target: ${targetReps ?? '?'})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: repsController,
                      enabled: isEnabled,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.only(
                          left: 12,
                          right: 60,
                          top: 8,
                          bottom: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: targetReps?.toString(),
                        suffixIcon: isEnabled
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      final currentValue =
                                          int.tryParse(repsController.text) ?? 0;
                                      final newValue =
                                          (currentValue - 1).clamp(0, 9999);
                                      repsController.text = newValue.toString();
                                      set['actualReps'] = newValue;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      final currentValue =
                                          int.tryParse(repsController.text) ?? 0;
                                      final newValue = currentValue + 1;
                                      repsController.text = newValue.toString();
                                      set['actualReps'] = newValue;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        set['actualReps'] = int.tryParse(value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Save button in new row (only show for current set if not completed)
          if (isCurrentSet && !isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isEnabled ? () => _saveSet(set, setIndex) : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Bottom sheet widget for selecting/creating alternatives
class _AlternativesBottomSheet extends StatefulWidget {
  final String originalWorkoutId;
  final String originalWorkoutName;
  final String? selectedAlternativeId;
  final List<WorkoutAlternative> alternatives;
  final Function(String? altId, String? altName) onAlternativeSelected;
  final Function(String name) onCreateAlternative;

  const _AlternativesBottomSheet({
    required this.originalWorkoutId,
    required this.originalWorkoutName,
    required this.selectedAlternativeId,
    required this.alternatives,
    required this.onAlternativeSelected,
    required this.onCreateAlternative,
  });

  @override
  State<_AlternativesBottomSheet> createState() =>
      _AlternativesBottomSheetState();
}

class _AlternativesBottomSheetState extends State<_AlternativesBottomSheet> {

  void _showCreateAlternativeDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Alternative'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Alternative Name',
            hintText: 'e.g., Dumbbell Press',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onCreateAlternative(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select Workout',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          // Original workout option
          RadioListTile<String?>(
            title: Text('Original: ${widget.originalWorkoutName}'),
            value: null,
            groupValue: widget.selectedAlternativeId,
            onChanged: (value) {
              widget.onAlternativeSelected(null, null);
            },
          ),
          // Alternative workouts
          ...widget.alternatives.map((alt) => RadioListTile<String?>(
                title: Text(alt.name),
                value: alt.id,
                groupValue: widget.selectedAlternativeId,
                onChanged: (value) {
                  widget.onAlternativeSelected(alt.id, alt.name);
                },
              )),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Create New Alternative'),
            onTap: _showCreateAlternativeDialog,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
