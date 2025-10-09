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
          'actualReps': 10,
          'actualWeight': 135.0,
          'completed': true
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
          ...sets.map((set) => _buildSetRow(context, workout, set)),
        ],
      ),
    );
  }

  Widget _buildSetRow(
      BuildContext context, Map<String, dynamic> workout, Map<String, dynamic> set) {
    final weightController = TextEditingController(
      text: set['actualWeight']?.toString() ?? set['suggestedWeight']?.toString() ?? '',
    );
    final repsController = TextEditingController(
      text: set['actualReps']?.toString() ?? set['suggestedReps']?.toString() ?? '',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Set number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: set['completed'] == true
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${set['setNumber']}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: set['completed'] == true
                          ? Theme.of(context).colorScheme.onPrimary
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: set['suggestedWeight']?.toString(),
                  ),
                  onChanged: (value) {
                    // TODO: Save to local database with debouncing
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
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: set['suggestedReps']?.toString(),
                  ),
                  onChanged: (value) {
                    // TODO: Save to local database with debouncing
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Complete checkbox
          Checkbox(
            value: set['completed'] as bool,
            onChanged: (value) {
              setState(() {
                set['completed'] = value ?? false;
                // TODO: Save to local database and trigger timer
              });
            },
          ),
        ],
      ),
    );
  }
}
