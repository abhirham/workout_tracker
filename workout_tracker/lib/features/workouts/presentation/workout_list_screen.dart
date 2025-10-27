import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/user_service.dart';
import '../../../shared/models/workout_alternative.dart';
import '../../../shared/models/completed_set.dart';
import '../../../shared/models/global_workout.dart';
import '../data/global_workout_repository.dart';
import '../../sync/services/progress_sync_service.dart';

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
  // Workouts loaded from database
  List<Map<String, dynamic>> workouts = [];
  bool isLoading = true;

  int currentWorkoutIndex = 0;
  int? currentSetIndex; // Track which set is currently editable
  int? timerSeconds; // Countdown timer (for rest between sets)
  bool isTimerRunning = false;
  Timer? _timer;
  String? selectedAlternativeId; // null = original workout
  String? selectedAlternativeName; // Name of selected alternative

  // Timer-based workout state
  WorkoutType? currentWorkoutType; // Type of current workout (weight or timer)
  int? workoutTimerSeconds; // Timer for timer-based workouts (e.g., plank duration)
  bool isWorkoutTimerRunning = false;
  Timer? _workoutTimer;
  int workoutTimerElapsed = 0; // Elapsed time for timer workouts

  // Text controllers for weight and reps inputs (persisted across rebuilds)
  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};

  @override
  void initState() {
    super.initState();
    // Load workouts from database first, then load progress
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkouts();
    });
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      isLoading = true;
    });

    final repository = ref.read(workoutTemplateRepositoryProvider);
    final globalWorkoutRepo = ref.read(globalWorkoutRepositoryProvider);
    final workoutsWithSets = await repository.getWorkoutsForDay(widget.dayId);

    // Fetch global workout details to get type
    final workoutsData = <Map<String, dynamic>>[];
    for (final workoutWithSets in workoutsWithSets) {
      final globalWorkout = await globalWorkoutRepo.getGlobalWorkoutById(
        workoutWithSets.workout.globalWorkoutId,
      );

      workoutsData.add({
        'id': workoutWithSets.workout.id,
        'name': workoutWithSets.workout.name,
        'globalWorkoutId': workoutWithSets.workout.globalWorkoutId,
        'type': globalWorkout?.type ?? WorkoutType.weight,  // Default to weight if not found
        'notes': workoutWithSets.workout.notes,
        'targetReps': workoutWithSets.workout.targetReps,  // Target reps string from admin (e.g., "12", "8-10", "AMRAP")
        'timerSeconds': workoutWithSets.timerConfig?.durationSeconds ?? 45,
        'sets': workoutWithSets.sets.map((setTemplate) {
          return {
            'setNumber': setTemplate.setNumber,
            'suggestedReps': setTemplate.suggestedReps,
            'suggestedWeight': setTemplate.suggestedWeight,
            'suggestedDuration': setTemplate.suggestedDuration,  // For timer workouts
            'actualReps': null,
            'actualWeight': null,
            'actualDuration': null,  // For timer workouts
            'completed': false,
          };
        }).toList(),
      });
    }

    setState(() {
      workouts = workoutsData;
      isLoading = false;
    });

    // Load progress after workouts are loaded
    if (workouts.isNotEmpty) {
      await _loadWorkoutProgress();
    }
  }

  Future<void> _loadWorkoutProgress() async {
    final repository = ref.read(completedSetRepositoryProvider);
    final userService = ref.read(userServiceProvider);
    final userId = userService.getCurrentUserIdOrThrow();
    final currentWorkout = workouts[currentWorkoutIndex];
    final workoutId = currentWorkout['id'] as String;
    final globalWorkoutId = currentWorkout['globalWorkoutId'] as String;
    final workoutType = currentWorkout['type'] as WorkoutType;

    // Get all completed sets for this workout in this week (filtered by alternative if selected)
    final completedSets = await repository.getCompletedSetsForWorkout(
      userId,
      widget.weekId,
      workoutId,
      alternativeId: selectedAlternativeId,
    );

    // Build a map of setNumber -> most recent completed set
    final Map<int, CompletedSet> latestSets = {};
    for (final completedSet in completedSets) {
      final setNumber = completedSet.setNumber;
      if (!latestSets.containsKey(setNumber) ||
          completedSet.completedAt.isAfter(latestSets[setNumber]!.completedAt)) {
        latestSets[setNumber] = completedSet;
      }
    }

    setState(() {
      // Set current workout type
      currentWorkoutType = workoutType;

      // Update workout data with loaded progress
      final sets = currentWorkout['sets'] as List;
      for (final set in sets) {
        final setNumber = set['setNumber'] as int;
        if (latestSets.containsKey(setNumber)) {
          final completedSet = latestSets[setNumber]!;
          if (workoutType == WorkoutType.weight) {
            set['actualWeight'] = completedSet.weight;
            set['actualReps'] = completedSet.reps;
          } else {
            set['actualDuration'] = completedSet.duration;
          }
          set['completed'] = true;
        } else {
          // No progress in this week - reset
          if (workoutType == WorkoutType.weight) {
            set['actualWeight'] = null;
            set['actualReps'] = _parseMinTargetReps(currentWorkout['targetReps'] as String?);
          } else {
            set['actualDuration'] = null;
          }
          set['completed'] = false;
        }
      }

      // Find the first uncompleted set, or default to 0
      currentSetIndex = sets.indexWhere((set) => set['completed'] == false);
      if (currentSetIndex == -1) {
        currentSetIndex = 0; // All completed, reset to first
      }
    });

    // Load last weights from previous weeks for pre-filling uncompleted sets (only for weight workouts)
    if (workoutType == WorkoutType.weight) {
      await _loadPreviousWeekWeights(userId, globalWorkoutId);
    }
  }

  Future<void> _loadPreviousWeekWeights(String userId, String globalWorkoutId) async {
    final repository = ref.read(completedSetRepositoryProvider);
    final currentWorkout = workouts[currentWorkoutIndex];
    final sets = currentWorkout['sets'] as List;

    // Determine if this is a phase boundary week
    // Phases are 4 weeks long: Week 1-4 (Phase 1), Week 5-8 (Phase 2), Week 9-12 (Phase 3), etc.
    final isPhaseStart = (widget.weekNumber - 1) % 4 == 0 && widget.weekNumber > 1;

    // For each uncompleted set, try to load the last weight from previous weeks
    for (final set in sets) {
      if (set['completed'] == false && set['actualWeight'] == null) {
        final setNumber = set['setNumber'] as int;
        CompletedSet? referenceSet;

        if (isPhaseStart) {
          // Phase boundary: look back to Week 1 of previous phase
          // e.g., Week 5 → Week 1, Week 9 → Week 5, Week 13 → Week 9
          final previousPhaseWeek1Number = widget.weekNumber - 4;
          final previousPhaseWeek1Id = 'week_$previousPhaseWeek1Number';

          referenceSet = await repository.getCompletedSetForSpecificWeek(
            userId,
            previousPhaseWeek1Id,
            globalWorkoutId,
            setNumber,
            alternativeId: selectedAlternativeId,
          );
        } else {
          // Within phase: use most recent completed set (previous week)
          referenceSet = await repository.getLastCompletedSetAcrossWeeks(
            userId,
            globalWorkoutId,
            setNumber,
            alternativeId: selectedAlternativeId,
          );
        }

        if (referenceSet != null) {
          // Progressive overload: add 5 lbs to the reference weight
          // This follows the rules:
          // - phase(n+1)week(1) = phase(n)week(1) + 5
          // - phase(n)week(m) = phase(n)week(m-1) + 5 (where m > 1)
          final newWeight = (referenceSet.weight ?? 0) + 5;
          setState(() {
            set['actualWeight'] = newWeight;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _workoutTimer?.cancel();
    // Dispose all text controllers
    for (var controller in _weightControllers.values) {
      controller.dispose();
    }
    for (var controller in _repsControllers.values) {
      controller.dispose();
    }
    _weightControllers.clear();
    _repsControllers.clear();
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
          final currentWorkout = workouts[currentWorkoutIndex];
          final sets = currentWorkout['sets'] as List;
          if (currentSetIndex! < sets.length - 1) {
            currentSetIndex = currentSetIndex! + 1;
          }
          timerSeconds = null;
        }
      });
    });
  }

  void _startWorkoutTimer(int durationSeconds) {
    setState(() {
      workoutTimerSeconds = durationSeconds;
      isWorkoutTimerRunning = true;
      workoutTimerElapsed = 0;
    });

    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (workoutTimerSeconds! > 0) {
          workoutTimerSeconds = workoutTimerSeconds! - 1;
          workoutTimerElapsed++;
        } else {
          timer.cancel();
          isWorkoutTimerRunning = false;
          // Auto-save the set with elapsed time
          final currentWorkout = workouts[currentWorkoutIndex];
          final sets = currentWorkout['sets'] as List;
          if (currentSetIndex != null && currentSetIndex! < sets.length) {
            final set = sets[currentSetIndex!];
            set['actualDuration'] = workoutTimerElapsed;
            _saveSet(set, currentSetIndex!);
          }
        }
      });
    });
  }

  int _stopWorkoutTimer() {
    _workoutTimer?.cancel();
    final elapsed = workoutTimerElapsed;
    setState(() {
      isWorkoutTimerRunning = false;
    });
    return elapsed;
  }

  void _clearTextControllers() {
    // Dispose and clear all text controllers
    for (var controller in _weightControllers.values) {
      controller.dispose();
    }
    for (var controller in _repsControllers.values) {
      controller.dispose();
    }
    _weightControllers.clear();
    _repsControllers.clear();
  }

  void _resetWorkoutState() {
    // Cancel any running timer
    _timer?.cancel();
    isTimerRunning = false;
    timerSeconds = null;
    // Clear text controllers when switching workout/alternative
    _clearTextControllers();
    // Load progress from database (will reset if no progress exists for current alternative)
    _loadWorkoutProgress();
  }

  // Parse targetReps string to get minimum target value
  // Examples: "6-8" -> 6, "12" -> 12, "AMRAP" -> null
  int? _parseMinTargetReps(String? targetReps) {
    if (targetReps == null || targetReps.isEmpty) return null;

    if (targetReps.contains('-')) {
      // Range format like "6-8" -> return 6
      final parts = targetReps.split('-');
      if (parts.isNotEmpty) {
        return int.tryParse(parts[0].trim());
      }
    } else if (targetReps.toUpperCase() != 'AMRAP') {
      // Single number like "12" -> return 12
      return int.tryParse(targetReps.trim());
    }
    // AMRAP or invalid -> return null
    return null;
  }

  // Update all incomplete sets after the current one with the new weight
  void _updateIncompleteSetWeights(int currentSetIndex, double newWeight) {
    final currentWorkout = workouts[currentWorkoutIndex];
    final sets = currentWorkout['sets'] as List;

    // Update all incomplete sets after the current one
    for (int i = currentSetIndex + 1; i < sets.length; i++) {
      if (sets[i]['completed'] == false) {
        sets[i]['actualWeight'] = newWeight;
      }
    }
  }

  Future<void> _saveSet(Map<String, dynamic> set, int setIndex) async {
    // Validate weight workout fields
    if (currentWorkoutType == WorkoutType.weight) {
      final weight = set['actualWeight'] as double?;
      final reps = set['actualReps'] as int?;
      final suggestedWeight = set['suggestedWeight'] as double?;
      final isBodyweightExercise = suggestedWeight == null;

      // For bodyweight exercises, allow weight = 0. For weighted exercises, require weight > 0.
      if (weight == null || (weight < 0) || (!isBodyweightExercise && weight == 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid weight'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (reps == null || reps <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid reps'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    // Save to database
    final repository = ref.read(completedSetRepositoryProvider);
    final userService = ref.read(userServiceProvider);
    final userId = userService.getCurrentUserIdOrThrow();
    final currentWorkout = workouts[currentWorkoutIndex];
    const uuid = Uuid();

    // Determine the actual workout name (use alternative name if selected, otherwise original name)
    final workoutName = selectedAlternativeName ?? (currentWorkout['name'] as String);

    // Handle timer vs weight workouts
    final CompletedSet completedSet;
    if (currentWorkoutType == WorkoutType.timer) {
      completedSet = CompletedSet(
        id: uuid.v4(),
        userId: userId,
        planId: widget.planId,
        weekId: widget.weekId,
        dayId: widget.dayId,
        workoutId: currentWorkout['id'] as String,
        workoutName: workoutName,  // Actual exercise name performed
        setNumber: set['setNumber'] as int,
        weight: null,
        reps: null,
        duration: set['actualDuration'] as int?,
        completedAt: DateTime.now(),
        syncedAt: null,  // Not yet synced to Firestore
        workoutAlternativeId: selectedAlternativeId, // null if original workout
      );
    } else {
      completedSet = CompletedSet(
        id: uuid.v4(),
        userId: userId,
        planId: widget.planId,
        weekId: widget.weekId,
        dayId: widget.dayId,
        workoutId: currentWorkout['id'] as String,
        workoutName: workoutName,  // Actual exercise name performed
        setNumber: set['setNumber'] as int,
        weight: set['actualWeight'] as double?,
        reps: set['actualReps'] as int?,
        duration: null,
        completedAt: DateTime.now(),
        syncedAt: null,  // Not yet synced to Firestore
        workoutAlternativeId: selectedAlternativeId, // null if original workout
      );
    }

    await repository.saveCompletedSet(completedSet);

    // Add to sync queue for upload to Firestore
    final progressSyncService = ref.read(progressSyncServiceProvider);
    await progressSyncService.enqueueCompletedSet(completedSet.id);

    setState(() {
      set['completed'] = true;

      // Start rest timer if not the last set (for both weight and timer workouts)
      final sets = currentWorkout['sets'] as List;
      if (setIndex < sets.length - 1) {
        _startTimer(); // Rest timer for all workout types
      } else {
        // Last set - move to next set index without timer
        currentSetIndex = setIndex + 1;
      }
    });
  }

  Future<void> _showAlternativesModal() async {
    final currentWorkout = workouts[currentWorkoutIndex];
    final originalWorkoutName = currentWorkout['name'] as String;
    final globalWorkoutId = currentWorkout['globalWorkoutId'] as String;

    // Load alternatives from repository
    final repository = ref.read(workoutAlternativeRepositoryProvider);
    final userService = ref.read(userServiceProvider);
    final userId = userService.getCurrentUserIdOrThrow();

    final alternatives = await repository.getAlternativesForWorkout(
      userId,
      globalWorkoutId,
    );

    if (!mounted) return;

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => _AlternativesBottomSheet(
        workoutName: globalWorkoutId,
        originalWorkoutName: originalWorkoutName,
        selectedAlternativeId: selectedAlternativeId,
        alternatives: alternatives,
        onAlternativeSelected: (String? altId, String? altName) {
          setState(() {
            selectedAlternativeId = altId;
            selectedAlternativeName = altName;
          });
          // Load progress for selected alternative (resets if no progress exists)
          _resetWorkoutState();
          Navigator.pop(context);
        },
        onCreateAlternative: (String name) async {
          // Create alternative in repository
          const uuid = Uuid();
          final newAlternative = WorkoutAlternative(
            id: uuid.v4(),
            userId: userId,
            globalWorkoutId: globalWorkoutId,
            name: name,
            createdAt: DateTime.now(),
          );

          await repository.createAlternative(newAlternative);

          // Auto-select the newly created alternative
          if (!mounted) return;
          setState(() {
            selectedAlternativeId = newAlternative.id;
            selectedAlternativeName = newAlternative.name;
            // Reset workout state for fresh start (new alternatives always start fresh)
            _resetWorkoutState();
          });

          if (!context.mounted) return;
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dayName),
        centerTitle: true,
        actions: !isLoading && workouts.isNotEmpty
            ? [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      '${currentWorkoutIndex + 1}/${workouts.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : workouts.isEmpty
              ? Center(
                  child: Text(
                    'No workouts for this day',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : _buildWorkoutContent(),
    );
  }

  Widget _buildWorkoutContent() {
    final currentWorkout = workouts[currentWorkoutIndex];
    final isLastWorkout = currentWorkoutIndex == workouts.length - 1;

    return Column(
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
                final currentWorkout = workouts[currentWorkoutIndex];
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
    );
  }

  Widget _buildNavigationButtons(BuildContext context, bool isLastWorkout) {
    // Get next exercise name if available
    String? nextExerciseName;
    if (!isLastWorkout && currentWorkoutIndex < workouts.length - 1) {
      nextExerciseName = workouts[currentWorkoutIndex + 1]['name'] as String;
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
                          // Cancel any running timer
                          _timer?.cancel();
                          isTimerRunning = false;
                          timerSeconds = null;
                          // Clear alternative selection when navigating to different workout
                          selectedAlternativeId = null;
                          selectedAlternativeName = null;
                        });
                        // Clear text controllers when switching workouts
                        _clearTextControllers();
                        // Load progress for previous workout
                        _loadWorkoutProgress();
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
                              // Cancel any running timer
                              _timer?.cancel();
                              isTimerRunning = false;
                              timerSeconds = null;
                              // Clear alternative selection when navigating to different workout
                              selectedAlternativeId = null;
                              selectedAlternativeName = null;
                            });
                            // Clear text controllers when switching workouts
                            _clearTextControllers();
                            // Load progress for next workout
                            _loadWorkoutProgress();
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
    // Allow editing if current set and not timer running (including completed sets)
    final isEnabled = isCurrentSet && !isTimerRunning;

    // Get weight from previous set if it exists and current set has no value
    double getInitialWeight() {
      if (set['actualWeight'] != null) {
        return set['actualWeight'] as double;
      }

      // Look for previous set's weight
      if (setIndex > 0) {
        final sets = workout['sets'] as List;
        final previousSet = sets[setIndex - 1];
        if (previousSet['actualWeight'] != null) {
          return previousSet['actualWeight'] as double;
        }
      }

      // Fall back to suggested weight, or 0 for bodyweight exercises
      return set['suggestedWeight'] as double? ?? 0.0;
    }

    final initialWeight = getInitialWeight();
    // Set the actual weight in the map if not already set
    if (set['actualWeight'] == null) {
      set['actualWeight'] = initialWeight;
    }

    // Get or create weight controller for this set
    if (!_weightControllers.containsKey(setIndex)) {
      _weightControllers[setIndex] = TextEditingController(
        text: initialWeight.toString(),
      );
    }
    final weightController = _weightControllers[setIndex]!;

    // Update controller text if the value in state changed (but preserve cursor)
    final currentWeight = set['actualWeight'] as double?;
    if (currentWeight != null && weightController.text != currentWeight.toString()) {
      final selection = weightController.selection;
      weightController.text = currentWeight.toString();
      // Restore cursor position if valid
      if (selection.isValid && selection.start <= weightController.text.length) {
        weightController.selection = selection;
      }
    }

    // Get target reps from workout (set by admin, e.g., "12", "8-10", "AMRAP")
    final targetReps = workout['targetReps'] as String?;
    final actualReps = set['actualReps'];

    // Parse targetReps to get default minimum value
    int? defaultReps;
    if (actualReps == null && targetReps != null && targetReps.isNotEmpty) {
      defaultReps = _parseMinTargetReps(targetReps);
    }

    // Get or create reps controller for this set
    final repsText = actualReps?.toString() ?? (defaultReps?.toString() ?? '');
    if (!_repsControllers.containsKey(setIndex)) {
      _repsControllers[setIndex] = TextEditingController(text: repsText);
    }
    final repsController = _repsControllers[setIndex]!;

    // Update controller text if the value in state changed (but preserve cursor)
    if (repsController.text != repsText && repsText.isNotEmpty) {
      final selection = repsController.selection;
      repsController.text = repsText;
      // Restore cursor position if valid
      if (selection.isValid && selection.start <= repsController.text.length) {
        repsController.selection = selection;
      }
    }

    return InkWell(
      onTap: isCompleted
          ? () {
              // Make completed set editable (keep it completed, just make it active)
              setState(() {
                currentSetIndex = setIndex;
                // Cancel any running timer
                _timer?.cancel();
                isTimerRunning = false;
                timerSeconds = null;
              });
            }
          : null,
      child: Container(
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

              // Conditional UI based on workout type
              if (currentWorkoutType == WorkoutType.timer) ...[
                // Timer workout UI
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duration',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isWorkoutTimerRunning && isCurrentSet
                                  ? '${workoutTimerSeconds}s'
                                  : isCompleted
                                      ? '${set['actualDuration'] ?? set['suggestedDuration']}s'
                                      : 'Target: ${set['suggestedDuration']}s',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isWorkoutTimerRunning && isCurrentSet
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Weight workout UI
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
                                                0.0;
                                        final newValue =
                                            (currentValue - 2.5).clamp(0.0, 9999.0);
                                        final newText = newValue.toStringAsFixed(1);
                                        // Update controller without losing cursor
                                        weightController.value = weightController.value.copyWith(
                                          text: newText,
                                          selection: TextSelection.collapsed(offset: newText.length),
                                        );
                                        setState(() {
                                          set['actualWeight'] = newValue;
                                          _updateIncompleteSetWeights(setIndex, newValue);
                                        });
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
                                        final newText = newValue.toStringAsFixed(1);
                                        // Update controller without losing cursor
                                        weightController.value = weightController.value.copyWith(
                                          text: newText,
                                          selection: TextSelection.collapsed(offset: newText.length),
                                        );
                                        setState(() {
                                          set['actualWeight'] = newValue;
                                          _updateIncompleteSetWeights(setIndex, newValue);
                                        });
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
                          final newWeight = double.tryParse(value);
                          setState(() {
                            set['actualWeight'] = newWeight;
                            if (newWeight != null) {
                              _updateIncompleteSetWeights(setIndex, newWeight);
                            }
                          });
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
                        targetReps != null ? 'Reps (Target: $targetReps)' : 'Reps',
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
                          hintText: targetReps,
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
                                        final newText = newValue.toString();
                                        // Update controller without losing cursor
                                        repsController.value = repsController.value.copyWith(
                                          text: newText,
                                          selection: TextSelection.collapsed(offset: newText.length),
                                        );
                                        setState(() {
                                          set['actualReps'] = newValue;
                                        });
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
                                        final newText = newValue.toString();
                                        // Update controller without losing cursor
                                        repsController.value = repsController.value.copyWith(
                                          text: newText,
                                          selection: TextSelection.collapsed(offset: newText.length),
                                        );
                                        setState(() {
                                          set['actualReps'] = newValue;
                                        });
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
            ],
          ),
          // Button row for current set
          if (isCurrentSet) ...[
            const SizedBox(height: 12),
            if (currentWorkoutType == WorkoutType.timer) ...[
              // Timer workout buttons
              if (!isCompleted && !isWorkoutTimerRunning)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isEnabled
                        ? () {
                            final duration = set['suggestedDuration'] as int?;
                            if (duration != null) {
                              _startWorkoutTimer(duration);
                            }
                          }
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Timer'),
                  ),
                )
              else if (isWorkoutTimerRunning)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final elapsed = _stopWorkoutTimer();
                      setState(() {
                        set['actualDuration'] = elapsed;
                      });
                      _saveSet(set, setIndex);
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop & Save'),
                  ),
                )
              else if (isCompleted)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isEnabled
                        ? () {
                            final duration = set['suggestedDuration'] as int?;
                            if (duration != null) {
                              _startWorkoutTimer(duration);
                            }
                          }
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Redo Timer'),
                  ),
                ),
            ] else ...[
              // Weight workout save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isEnabled ? () => _saveSet(set, setIndex) : null,
                  child: const Text('Save'),
                ),
              ),
            ],
          ],
        ],
        ),
      ),
    );
  }
}

// Bottom sheet widget for selecting/creating alternatives
class _AlternativesBottomSheet extends StatefulWidget {
  final String workoutName;
  final String originalWorkoutName;
  final String? selectedAlternativeId;
  final List<WorkoutAlternative> alternatives;
  final Function(String? altId, String? altName) onAlternativeSelected;
  final Function(String name) onCreateAlternative;

  const _AlternativesBottomSheet({
    required this.workoutName,
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
