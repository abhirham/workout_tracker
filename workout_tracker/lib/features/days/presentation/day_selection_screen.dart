import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_tracker/core/database/app_database.dart';
import 'package:workout_tracker/core/database/database_provider.dart';
import 'package:workout_tracker/core/services/user_service.dart';
import 'package:workout_tracker/features/workouts/data/workout_template_repository.dart';
import 'package:workout_tracker/features/workouts/data/completed_set_repository.dart';

class DaySelectionScreen extends ConsumerStatefulWidget {
  final String planId;
  final String weekId;
  final String weekName;

  const DaySelectionScreen({
    super.key,
    required this.planId,
    required this.weekId,
    required this.weekName,
  });

  @override
  ConsumerState<DaySelectionScreen> createState() => _DaySelectionScreenState();
}

class _DaySelectionScreenState extends ConsumerState<DaySelectionScreen> {
  List<Day> days = [];
  Map<String, int> workoutCounts = {};
  Map<String, bool> dayCompletionStatus = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDays();
    });
  }

  int get weekNumber {
    // Extract week number from weekId (format: 'week_1', 'week_2', etc.)
    final match = RegExp(r'week_(\d+)').firstMatch(widget.weekId);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  Future<void> _loadDays() async {
    setState(() {
      isLoading = true;
    });

    final repository = ref.read(dayRepositoryProvider);
    final workoutRepository = ref.read(workoutTemplateRepositoryProvider);
    final completedSetRepository = ref.read(completedSetRepositoryProvider);
    final userService = ref.read(userServiceProvider);

    final userId = userService.getCurrentUserIdOrThrow();
    final loadedDays = await repository.getDaysForWeek(widget.weekId);

    // Load workout counts and completion status for each day
    final counts = <String, int>{};
    final completionStatus = <String, bool>{};

    for (final day in loadedDays) {
      counts[day.id] = await repository.getWorkoutCountForDay(day.id);

      // Check if day is completed
      completionStatus[day.id] = await _isDayCompleted(
        userId,
        day.id,
        workoutRepository,
        completedSetRepository,
      );
    }

    setState(() {
      days = loadedDays;
      workoutCounts = counts;
      dayCompletionStatus = completionStatus;
      isLoading = false;
    });
  }

  /// Check if a day is completed (all workouts have all sets completed)
  Future<bool> _isDayCompleted(
    String userId,
    String dayId,
    WorkoutTemplateRepository workoutRepository,
    CompletedSetRepository completedSetRepository,
  ) async {
    // Get all workouts for this day
    final workoutsWithSets = await workoutRepository.getWorkoutsForDay(dayId);

    if (workoutsWithSets.isEmpty) return false;

    // Check each workout
    for (final workoutWithSets in workoutsWithSets) {
      final workout = workoutWithSets.workout;
      final totalSets = workoutWithSets.sets.length;

      if (totalSets == 0) continue;

      // Get completed sets for this workout
      final completedSets = await completedSetRepository.getCompletedSetsForWorkout(
        userId,
        widget.weekId,
        workout.id,
      );

      // Check if all sets are completed
      if (completedSets.length < totalSets) {
        return false; // Not all sets completed
      }
    }

    return true; // All workouts have all sets completed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.weekName),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : days.isEmpty
              ? Center(
                  child: Text(
                    'No days found for this week',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    return _buildDayCard(context, day);
                  },
                ),
    );
  }

  Widget _buildDayCard(BuildContext context, Day day) {
    final isCompleted = dayCompletionStatus[day.id] ?? false;
    final workoutCount = workoutCounts[day.id] ?? 0;

    return Card(
      child: InkWell(
        onTap: () {
          context.pushNamed(
            'workouts',
            pathParameters: {
              'planId': widget.planId,
              'weekId': widget.weekId,
              'dayId': day.id,
            },
            queryParameters: {
              'dayName': day.name,
              'weekNumber': weekNumber.toString(),
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isCompleted
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isCompleted)
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                )
              else
                const SizedBox(height: 18),
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.dayNumber}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isCompleted
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                day.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '$workoutCount exercises',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
