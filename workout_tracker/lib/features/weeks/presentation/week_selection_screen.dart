import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_tracker/core/database/app_database.dart';
import 'package:workout_tracker/core/database/database_provider.dart';
import 'package:workout_tracker/core/services/user_service.dart';
import 'package:workout_tracker/features/workouts/data/workout_template_repository.dart';
import 'package:workout_tracker/features/workouts/data/completed_set_repository.dart';

class WeekSelectionScreen extends ConsumerStatefulWidget {
  final String planId;
  final String planName;

  const WeekSelectionScreen({
    super.key,
    required this.planId,
    required this.planName,
  });

  @override
  ConsumerState<WeekSelectionScreen> createState() => _WeekSelectionScreenState();
}

class _WeekSelectionScreenState extends ConsumerState<WeekSelectionScreen> {
  List<Week> weeks = [];
  Map<String, int> dayCounts = {};
  Map<String, int> completedDayCounts = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWeeks();
    });
  }

  Future<void> _loadWeeks() async {
    setState(() {
      isLoading = true;
    });

    final repository = ref.read(weekRepositoryProvider);
    final dayRepository = ref.read(dayRepositoryProvider);
    final workoutRepository = ref.read(workoutTemplateRepositoryProvider);
    final completedSetRepository = ref.read(completedSetRepositoryProvider);
    final userService = ref.read(userServiceProvider);

    final userId = userService.getCurrentUserIdOrThrow();
    final loadedWeeks = await repository.getWeeksForPlan(widget.planId);

    // Load day counts and completion status for each week
    final counts = <String, int>{};
    final completedCounts = <String, int>{};

    for (final week in loadedWeeks) {
      final days = await dayRepository.getDaysForWeek(week.id);
      counts[week.id] = days.length;

      // Count completed days
      int completedDays = 0;
      for (final day in days) {
        final isCompleted = await _isDayCompleted(
          userId,
          week.id,
          day.id,
          workoutRepository,
          completedSetRepository,
        );
        if (isCompleted) completedDays++;
      }
      completedCounts[week.id] = completedDays;
    }

    setState(() {
      weeks = loadedWeeks;
      dayCounts = counts;
      completedDayCounts = completedCounts;
      isLoading = false;
    });
  }

  /// Check if a day is completed (all workouts have all sets completed)
  Future<bool> _isDayCompleted(
    String userId,
    String weekId,
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
        weekId,
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
        title: Text(widget.planName),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : weeks.isEmpty
              ? Center(
                  child: Text(
                    'No weeks found for this plan',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: weeks.length,
                  itemBuilder: (context, index) {
                    final week = weeks[index];
                    return _buildWeekCard(context, week);
                  },
                ),
    );
  }

  Widget _buildWeekCard(BuildContext context, Week week) {
    final daysCompleted = completedDayCounts[week.id] ?? 0;
    final totalDays = dayCounts[week.id] ?? 0;
    final progress = totalDays > 0 ? daysCompleted / totalDays : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.pushNamed(
            'days',
            pathParameters: {
              'planId': widget.planId,
              'weekId': week.id,
            },
            queryParameters: {'weekName': week.name},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'W${week.weekNumber}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      week.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$daysCompleted of $totalDays days completed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
