import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkoutListScreen extends ConsumerStatefulWidget {
  final String planId;
  final String weekId;
  final String dayId;
  final String dayName;

  const WorkoutListScreen({
    super.key,
    required this.planId,
    required this.weekId,
    required this.dayId,
    required this.dayName,
  });

  @override
  ConsumerState<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends ConsumerState<WorkoutListScreen> {
  // TODO: Replace with actual data from repository
  final mockWorkouts = [
    {
      'id': 'workout_1',
      'name': 'Bench Press',
      'notes': 'Focus on slow eccentric',
      'sets': [
        {
          'setNumber': 1,
          'suggestedReps': 10,
          'suggestedWeight': 135.0,
          'actualReps': null,
          'actualWeight': null,
          'completed': false
        },
        {
          'setNumber': 2,
          'suggestedReps': 8,
          'suggestedWeight': 155.0,
          'actualReps': null,
          'actualWeight': null,
          'completed': false
        },
        {
          'setNumber': 3,
          'suggestedReps': 6,
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
          'suggestedReps': 12,
          'suggestedWeight': 75.0,
          'actualReps': null,
          'actualWeight': null,
          'completed': false
        },
        {
          'setNumber': 2,
          'suggestedReps': 10,
          'suggestedWeight': 85.0,
          'actualReps': null,
          'actualWeight': null,
          'completed': false
        },
        {
          'setNumber': 3,
          'suggestedReps': 8,
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
          'suggestedReps': 12,
          'suggestedWeight': 60.0,
          'actualReps': null,
          'actualWeight': null,
          'completed': false
        },
        {
          'setNumber': 2,
          'suggestedReps': 10,
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
      _startTimer();
    });
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
            Container(
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
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
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
        child: Row(
          children: [
            if (currentWorkoutIndex > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      currentWorkoutIndex--;
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
                        });
                      },
                child: Text(isLastWorkout ? 'Finish' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context, Map<String, dynamic> workout) {
    final sets = workout['sets'] as List;
    final completedSets = sets.where((s) => s['completed'] == true).length;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout['name'] as String,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
    final repsController = TextEditingController(
      text: set['actualReps']?.toString() ??
          set['suggestedReps']?.toString() ??
          '',
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
                      'Weight (kg)',
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
                                          (currentValue - 1).clamp(0, 9999);
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
                                      final newValue = currentValue + 1;
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

              // Reps input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reps',
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
                        hintText: set['suggestedReps']?.toString(),
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
