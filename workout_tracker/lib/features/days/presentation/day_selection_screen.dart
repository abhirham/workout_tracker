import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_tracker/core/database/app_database.dart';
import 'package:workout_tracker/core/database/database_provider.dart';

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
    final loadedDays = await repository.getDaysForWeek(widget.weekId);

    // Load workout counts for each day
    final counts = <String, int>{};
    for (final day in loadedDays) {
      counts[day.id] = await repository.getWorkoutCountForDay(day.id);
    }

    setState(() {
      days = loadedDays;
      workoutCounts = counts;
      isLoading = false;
    });
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
    // TODO: Check if day is completed (requires progress tracking)
    final isCompleted = false;
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
