import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/models/workout_alternative.dart';
import '../../../shared/models/completed_set.dart';
import '../../../shared/models/global_workout.dart';
import '../data/global_workout_repository.dart';
import '../../sync/services/progress_sync_service.dart';
import '../../settings/presentation/widgets/rest_timer_settings_bottom_sheet.dart';
import '../../settings/data/user_preferences_repository.dart';

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

class _WorkoutListScreenState extends ConsumerState<WorkoutListScreen>
    with WidgetsBindingObserver {
  // Workouts loaded from database
  List<Map<String, dynamic>> workouts = [];
  bool isLoading = true;

  int currentWorkoutIndex = 0;
  int? currentSetIndex; // Track which set is currently editable
  int?
  timerSeconds; // Countdown timer (for rest between sets) - calculated value
  bool isTimerRunning = false;
  Timer? _timer;
  int? _timerWorkoutIndex; // Track which workout the timer belongs to
  int? _timerSetIndex; // Track which set the timer was started for
  String? selectedAlternativeId; // null = original workout
  String? selectedAlternativeName; // Name of selected alternative

  // Timer-based workout state
  WorkoutType? currentWorkoutType; // Type of current workout (weight or timer)
  int?
  workoutTimerSeconds; // Timer for timer-based workouts (e.g., plank duration) - calculated value
  bool isWorkoutTimerRunning = false;
  Timer? _workoutTimer;
  int workoutTimerElapsed = 0; // Elapsed time for timer workouts

  // Timestamp-based timer tracking (for background resilience)
  DateTime? _restTimerEndTime; // When rest timer should complete
  DateTime? _workoutTimerStartTime; // When workout timer started

  // Text controllers for weight and reps inputs (persisted across rebuilds)
  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};

  // User's preferred rest timer duration (loaded from database)
  int _restTimerDuration = 45; // Default fallback value

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load workouts from database first, then load progress
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkouts();
      _loadRestTimerPreference();
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
        'type':
            globalWorkout?.type ??
            WorkoutType.weight, // Default to weight if not found
        'notes': workoutWithSets.workout.notes,
        'targetReps': workoutWithSets
            .workout
            .targetReps, // Target reps string from admin (e.g., "12", "8-10", "AMRAP")
        'timerSeconds': workoutWithSets.timerConfig?.durationSeconds ?? 45,
        'sets': workoutWithSets.sets.map((setTemplate) {
          return {
            'setNumber': setTemplate.setNumber,
            'suggestedReps': setTemplate.suggestedReps,
            'suggestedWeight': setTemplate.suggestedWeight,
            'suggestedDuration':
                setTemplate.suggestedDuration, // For timer workouts
            'actualReps': null,
            'actualWeight': null,
            'actualDuration': null, // For timer workouts
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

  Future<void> _loadRestTimerPreference() async {
    try {
      final userService = ref.read(userServiceProvider);
      final userId = userService.getCurrentUserIdOrThrow();
      final repository = ref.read(userPreferencesRepositoryProvider);

      final duration = await repository.getDefaultRestTimer(userId);

      setState(() {
        _restTimerDuration = duration;
      });
    } catch (e) {
      debugPrint('[RestTimer] Failed to load preference: $e');
      // Keep default value (45 seconds) on error
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
          completedSet.completedAt.isAfter(
            latestSets[setNumber]!.completedAt,
          )) {
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
            set['actualReps'] = _parseMinTargetReps(
              currentWorkout['targetReps'] as String?,
            );
          } else {
            set['actualDuration'] = null;
          }
          set['completed'] = false;
        }
      }

      // Find the first uncompleted set
      // If all sets are completed, don't auto-select any set
      // User must tap checkbox to edit a completed set
      currentSetIndex = sets.indexWhere((set) => set['completed'] == false);
      if (currentSetIndex == -1) {
        currentSetIndex = null; // All completed, no set is active
      }

      // If there's an active timer for this workout, preserve the original set index
      // This prevents skipping sets when user navigates away and comes back
      if (isTimerRunning &&
          _timerWorkoutIndex != null &&
          _timerWorkoutIndex == currentWorkoutIndex &&
          _timerSetIndex != null) {
        debugPrint(
          '[RestTimer] Preserving timer set index $_timerSetIndex instead of first incomplete $currentSetIndex',
        );
        currentSetIndex = _timerSetIndex;
      }
    });

    // Load last weights from previous weeks for pre-filling uncompleted sets (only for weight workouts)
    if (workoutType == WorkoutType.weight) {
      await _loadPreviousWeekWeights(userId, globalWorkoutId);
    }
  }

  Future<void> _loadPreviousWeekWeights(
    String userId,
    String globalWorkoutId,
  ) async {
    final repository = ref.read(completedSetRepositoryProvider);
    final currentWorkout = workouts[currentWorkoutIndex];
    final sets = currentWorkout['sets'] as List;

    // Determine if this is a phase boundary week
    // Phases are 4 weeks long: Week 1-4 (Phase 1), Week 5-8 (Phase 2), Week 9-12 (Phase 3), etc.
    final isPhaseStart =
        (widget.weekNumber - 1) % 4 == 0 && widget.weekNumber > 1;

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
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _workoutTimer?.cancel();
    // Cancel any pending notifications
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.cancelRestNotification();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  /// Handle app resuming from background
  void _handleAppResumed() {
    final now = DateTime.now();
    final notificationService = ref.read(notificationServiceProvider);

    // Check rest timer (for weight workouts)
    if (isTimerRunning && _restTimerEndTime != null) {
      final remaining = _restTimerEndTime!.difference(now).inSeconds;

      if (remaining <= 0) {
        // Timer completed while backgrounded
        debugPrint('[RestTimer] Completed while backgrounded');
        _timer?.cancel();
        setState(() {
          isTimerRunning = false;
          timerSeconds = null;
          _restTimerEndTime = null;

          // Only auto-advance if we're still on the same workout AND set where timer was started
          // This prevents skipping sets if user navigated away and came back while backgrounded
          if (_timerWorkoutIndex != null &&
              _timerWorkoutIndex == currentWorkoutIndex &&
              _timerSetIndex != null &&
              _timerSetIndex == currentSetIndex) {
            debugPrint(
              '[RestTimer] Auto-advancing to next set (still on workout $_timerWorkoutIndex, set $_timerSetIndex)',
            );
            _advanceToNextSet();
          } else {
            debugPrint(
              '[RestTimer] Not auto-advancing (timer from workout $_timerWorkoutIndex set $_timerSetIndex, now on workout $currentWorkoutIndex set $currentSetIndex)',
            );
          }
          _timerWorkoutIndex = null;
          _timerSetIndex = null;
        });
        // Cancel notification since user returned
        notificationService.cancelRestNotification();
      } else {
        // Update remaining time
        setState(() {
          timerSeconds = remaining;
        });
        // Cancel notification since user returned before completion
        notificationService.cancelRestNotification();
      }
    }

    // Check workout timer (for timer-based exercises like plank)
    if (isWorkoutTimerRunning && _workoutTimerStartTime != null) {
      final elapsed = now.difference(_workoutTimerStartTime!).inSeconds;
      final currentWorkout = workouts.isNotEmpty
          ? workouts[currentWorkoutIndex]
          : null;

      if (currentWorkout != null) {
        final sets = currentWorkout['sets'] as List;
        final targetDuration =
            currentSetIndex != null && currentSetIndex! < sets.length
            ? (sets[currentSetIndex!]['suggestedDuration'] as int? ?? 60)
            : 60;

        if (elapsed >= targetDuration) {
          // Workout timer completed while backgrounded
          debugPrint(
            '[WorkoutTimer] Completed while backgrounded, auto-saving',
          );
          _workoutTimer?.cancel();
          setState(() {
            isWorkoutTimerRunning = false;
            workoutTimerElapsed = elapsed;
            workoutTimerSeconds = 0;
          });
          // Auto-save the set
          if (currentSetIndex != null && currentSetIndex! < sets.length) {
            final set = sets[currentSetIndex!];
            set['actualDuration'] = elapsed;
            _saveSet(set, currentSetIndex!);
          }
        } else {
          // Update elapsed time
          setState(() {
            workoutTimerElapsed = elapsed;
            workoutTimerSeconds = targetDuration - elapsed;
          });
        }
      }
    }
  }

  /// Advance to the next uncompleted set (helper method)
  void _advanceToNextSet() {
    if (workouts.isEmpty || currentWorkoutIndex >= workouts.length) return;

    // Only advance if we're on the workout where the timer was started
    // This prevents advancing the wrong exercise if user navigated away
    // Return if: timer index is null OR it's a different workout
    debugPrint('og: $_timerWorkoutIndex, currently on $currentWorkoutIndex');
    if (_timerWorkoutIndex == null ||
        _timerWorkoutIndex != currentWorkoutIndex) {
      debugPrint(
        '[RestTimer] Not advancing - timer from workout $_timerWorkoutIndex, currently on $currentWorkoutIndex',
      );
      return;
    }

    final currentWorkout = workouts[currentWorkoutIndex];
    final sets = currentWorkout['sets'] as List;

    if (currentSetIndex != null && currentSetIndex! < sets.length - 1) {
      // Find the next uncompleted set starting from current + 1
      final nextUncompletedIndex = sets
          .skip(currentSetIndex! + 1)
          .toList()
          .indexWhere((set) => set['completed'] == false);

      setState(() {
        if (nextUncompletedIndex != -1) {
          // Found an uncompleted set
          currentSetIndex = currentSetIndex! + 1 + nextUncompletedIndex;
        } else {
          // All remaining sets are completed, don't select any
          currentSetIndex = null;
        }
      });
    }
  }

  void _startTimer() {
    final now = DateTime.now();
    final endTime = now.add(Duration(seconds: _restTimerDuration));

    setState(() {
      _restTimerEndTime = endTime;
      timerSeconds = _restTimerDuration;
      isTimerRunning = true;
      _timerWorkoutIndex =
          currentWorkoutIndex; // Track which workout this timer belongs to
      _timerSetIndex =
          currentSetIndex; // Track which set this timer was started for
    });

    debugPrint(
      '[RestTimer] Started for workout $currentWorkoutIndex, set $currentSetIndex, duration ${_restTimerDuration}s, will complete at ${endTime.toIso8601String()}',
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final remaining = _restTimerEndTime!.difference(now).inSeconds;

      setState(() {
        if (remaining > 0) {
          timerSeconds = remaining;
        } else {
          // Timer completed
          timer.cancel();
          isTimerRunning = false;
          timerSeconds = null;
          _restTimerEndTime = null;

          debugPrint('[RestTimer] Completed, showing notification');

          // Show notification
          final notificationService = ref.read(notificationServiceProvider);
          notificationService.showRestCompleteNotification();

          // Only auto-advance if we're still on the same workout AND set where timer was started
          // This prevents skipping sets if user navigated away and came back
          if (_timerWorkoutIndex != null &&
              _timerWorkoutIndex == currentWorkoutIndex &&
              _timerSetIndex != null &&
              _timerSetIndex == currentSetIndex) {
            debugPrint(
              '[RestTimer] Auto-advancing to next set (still on workout $_timerWorkoutIndex, set $_timerSetIndex)',
            );
            _advanceToNextSet();
          } else {
            debugPrint(
              '[RestTimer] Not auto-advancing (timer from workout $_timerWorkoutIndex set $_timerSetIndex, now on workout $currentWorkoutIndex set $currentSetIndex)',
            );
          }

          _timerWorkoutIndex = null;
          _timerSetIndex = null;
        }
      });
    });
  }

  void _startWorkoutTimer(int durationSeconds) {
    final now = DateTime.now();

    setState(() {
      _workoutTimerStartTime = now;
      workoutTimerSeconds = durationSeconds;
      isWorkoutTimerRunning = true;
      workoutTimerElapsed = 0;
    });

    debugPrint(
      '[WorkoutTimer] Started at ${now.toIso8601String()}, duration: ${durationSeconds}s',
    );

    _workoutTimer?.cancel();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final elapsed = now.difference(_workoutTimerStartTime!).inSeconds;
      final remaining = durationSeconds - elapsed;

      setState(() {
        workoutTimerElapsed = elapsed;
        if (remaining > 0) {
          workoutTimerSeconds = remaining;
        } else {
          // Timer completed
          timer.cancel();
          isWorkoutTimerRunning = false;
          workoutTimerSeconds = 0;
          _workoutTimerStartTime = null;

          debugPrint('[WorkoutTimer] Completed, elapsed: ${elapsed}s');

          // Auto-save the set with elapsed time
          final currentWorkout = workouts[currentWorkoutIndex];
          final sets = currentWorkout['sets'] as List;
          if (currentSetIndex != null && currentSetIndex! < sets.length) {
            final set = sets[currentSetIndex!];
            set['actualDuration'] = elapsed;
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
      _workoutTimerStartTime = null;
    });
    debugPrint('[WorkoutTimer] Stopped manually, elapsed: ${elapsed}s');
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
    // Cancel any running timers (user is switching alternatives, start fresh)
    _timer?.cancel();
    _workoutTimer?.cancel();

    // Reset timer state
    setState(() {
      isTimerRunning = false;
      timerSeconds = null;
      _restTimerEndTime = null;
      _timerWorkoutIndex = null;
      _timerSetIndex = null;
      isWorkoutTimerRunning = false;
      workoutTimerSeconds = null;
      _workoutTimerStartTime = null;
    });

    // Cancel notifications
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.cancelRestNotification();

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
      if (weight == null ||
          (weight < 0) ||
          (!isBodyweightExercise && weight == 0)) {
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
    final workoutName =
        selectedAlternativeName ?? (currentWorkout['name'] as String);

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
        workoutName: workoutName, // Actual exercise name performed
        setNumber: set['setNumber'] as int,
        weight: null,
        reps: null,
        duration: set['actualDuration'] as int?,
        completedAt: DateTime.now(),
        syncedAt: null, // Not yet synced to Firestore
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
        workoutName: workoutName, // Actual exercise name performed
        setNumber: set['setNumber'] as int,
        weight: set['actualWeight'] as double?,
        reps: set['actualReps'] as int?,
        duration: null,
        completedAt: DateTime.now(),
        syncedAt: null, // Not yet synced to Firestore
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
        _startTimer(); // Rest timer will auto-advance to next uncompleted set
      } else {
        // Last set completed - no set should be active
        // User must tap checkbox to edit any completed set
        currentSetIndex = null;
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
    return GestureDetector(
      // Tap anywhere to hide keyboard
      onTap: () {
        // Unfocus any active text field to hide keyboard
        FocusScope.of(context).unfocus();
      },
      // Allow taps to pass through to child widgets
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.dayName),
          centerTitle: true,
          actions: !isLoading && workouts.isNotEmpty
              ? [
                  // Gear icon for rest timer settings
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Rest Timer Settings',
                    onPressed: () {
                      showRestTimerSettings(context).then((_) {
                        // Reload preference after settings are changed
                        _loadRestTimerPreference();
                      });
                    },
                  ),
                  // Exercise counter
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
      ),
    );
  }

  Widget _buildWorkoutContent() {
    final currentWorkout = workouts[currentWorkoutIndex];
    final isLastWorkout = currentWorkoutIndex == workouts.length - 1;

    // Check if keyboard is open
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return Column(
      children: [
        if (isTimerRunning && timerSeconds != null)
          InkWell(
            onTap: () {
              // Skip timer
              _timer?.cancel();
              debugPrint('[RestTimer] Skipped by user');

              // Cancel notification
              final notificationService = ref.read(notificationServiceProvider);
              notificationService.cancelRestNotification();

              setState(() {
                // Move to next set FIRST (before resetting timer indices)
                // User is actively on this screen, so always advance
                _advanceToNextSet();

                // Then reset timer state
                isTimerRunning = false;
                timerSeconds = null;
                _restTimerEndTime = null;
                _timerWorkoutIndex = null;
                _timerSetIndex = null;
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
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(tap to skip)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
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
        // Hide navigation buttons when keyboard is open
        if (!isKeyboardOpen) _buildNavigationButtons(context, isLastWorkout),
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
            color: Colors.black.withValues(alpha: 0.1),
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
                        // Cancel only workout timer (exercise-specific like plank)
                        // Keep rest timer running (it will persist across exercises)
                        _workoutTimer?.cancel();

                        setState(() {
                          currentWorkoutIndex--;
                          // Keep rest timer state (isTimerRunning, timerSeconds, _restTimerEndTime)
                          // Cancel only workout timer state
                          isWorkoutTimerRunning = false;
                          workoutTimerSeconds = null;
                          _workoutTimerStartTime = null;
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
                            // Finish workout: cancel all timers and notifications
                            _timer?.cancel();
                            _workoutTimer?.cancel();
                            final notificationService = ref.read(
                              notificationServiceProvider,
                            );
                            notificationService.cancelRestNotification();

                            Navigator.of(context).pop();
                          }
                        : () {
                            // Next exercise: keep rest timer running, cancel only workout timer
                            _workoutTimer?.cancel();

                            setState(() {
                              currentWorkoutIndex++;
                              // Keep rest timer state (isTimerRunning, timerSeconds, _restTimerEndTime)
                              // Cancel only workout timer state
                              isWorkoutTimerRunning = false;
                              workoutTimerSeconds = null;
                              _workoutTimerStartTime = null;
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
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
    int setIndex,
  ) {
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

    // Get or create weight controller for this set
    if (!_weightControllers.containsKey(setIndex)) {
      // Only set initial weight when first creating the controller
      final weightToUse = set['actualWeight'] as double? ?? initialWeight;
      _weightControllers[setIndex] = TextEditingController(
        text: weightToUse.toString(),
      );
      // Set the actual weight in state only if not already set
      if (set['actualWeight'] == null) {
        set['actualWeight'] = weightToUse;
      }
    }
    final weightController = _weightControllers[setIndex]!;

    // Update controller text only if the numeric value actually changed
    // This prevents interfering with user's text editing (e.g., typing "30" vs "30.0")
    final currentWeight = set['actualWeight'] as double?;
    final controllerWeight = double.tryParse(weightController.text);
    // Only update if the numeric values differ (handles programmatic changes like increment buttons)
    if (currentWeight != controllerWeight) {
      weightController.text = currentWeight?.toString() ?? '';
    }

    // Get target reps from workout (set by admin, e.g., "12", "8-10", "AMRAP")
    final targetReps = workout['targetReps'] as String?;
    final actualReps = set['actualReps'];

    // Parse targetReps to get default minimum value
    int? defaultReps;
    if (targetReps != null && targetReps.isNotEmpty) {
      defaultReps = _parseMinTargetReps(targetReps);
    }

    // Get or create reps controller for this set
    if (!_repsControllers.containsKey(setIndex)) {
      // Only set initial reps when first creating the controller
      final repsToUse = actualReps ?? defaultReps;
      final initialRepsText = repsToUse?.toString() ?? '';
      _repsControllers[setIndex] = TextEditingController(text: initialRepsText);
      // Set the actual reps in state only if not already set
      if (set['actualReps'] == null && repsToUse != null) {
        set['actualReps'] = repsToUse;
      }
    }
    final repsController = _repsControllers[setIndex]!;

    // Update controller text only if the numeric value actually changed
    // This prevents interfering with user's text editing
    final controllerReps = int.tryParse(repsController.text);
    // Only update if the numeric values differ (handles programmatic changes like increment buttons)
    if (actualReps != controllerReps) {
      repsController.text = actualReps?.toString() ?? '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentSet && !isCompleted
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Set number checkbox
              // IMPORTANT: For completed sets, this is the ONLY way to put them in edit mode
              // Tapping the checkbox makes a completed set editable so users can modify it
              InkWell(
                onTap: isCompleted
                    ? () {
                        // Make completed set editable by making it the current set
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isCurrentSet
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: weightController,
                          enabled: isEnabled,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
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
                                              double.tryParse(
                                                weightController.text,
                                              ) ??
                                              0.0;
                                          final newValue = (currentValue - 2.5)
                                              .clamp(0.0, 9999.0);
                                          final newText = newValue
                                              .toStringAsFixed(1);
                                          // Update controller without losing cursor
                                          weightController.value =
                                              weightController.value.copyWith(
                                                text: newText,
                                                selection:
                                                    TextSelection.collapsed(
                                                      offset: newText.length,
                                                    ),
                                              );
                                          setState(() {
                                            set['actualWeight'] = newValue;
                                            _updateIncompleteSetWeights(
                                              setIndex,
                                              newValue,
                                            );
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.remove,
                                            size: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          final currentValue =
                                              double.tryParse(
                                                weightController.text,
                                              ) ??
                                              0;
                                          final newValue = currentValue + 5;
                                          final newText = newValue
                                              .toStringAsFixed(1);
                                          // Update controller without losing cursor
                                          weightController.value =
                                              weightController.value.copyWith(
                                                text: newText,
                                                selection:
                                                    TextSelection.collapsed(
                                                      offset: newText.length,
                                                    ),
                                              );
                                          setState(() {
                                            set['actualWeight'] = newValue;
                                            _updateIncompleteSetWeights(
                                              setIndex,
                                              newValue,
                                            );
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            Icons.add,
                                            size: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
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
                                _updateIncompleteSetWeights(
                                  setIndex,
                                  newWeight,
                                );
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
                          targetReps != null
                              ? 'Reps (Target: $targetReps)'
                              : 'Reps',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                                              int.tryParse(
                                                repsController.text,
                                              ) ??
                                              0;
                                          final newValue = (currentValue - 1)
                                              .clamp(0, 9999);
                                          final newText = newValue.toString();
                                          // Update controller without losing cursor
                                          repsController.value = repsController
                                              .value
                                              .copyWith(
                                                text: newText,
                                                selection:
                                                    TextSelection.collapsed(
                                                      offset: newText.length,
                                                    ),
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
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          final currentValue =
                                              int.tryParse(
                                                repsController.text,
                                              ) ??
                                              0;
                                          final newValue = currentValue + 1;
                                          final newText = newValue.toString();
                                          // Update controller without losing cursor
                                          repsController.value = repsController
                                              .value
                                              .copyWith(
                                                text: newText,
                                                selection:
                                                    TextSelection.collapsed(
                                                      offset: newText.length,
                                                    ),
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
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
          ...widget.alternatives.map(
            (alt) => RadioListTile<String?>(
              title: Text(alt.name),
              value: alt.id,
              groupValue: widget.selectedAlternativeId,
              onChanged: (value) {
                widget.onAlternativeSelected(alt.id, alt.name);
              },
            ),
          ),
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
