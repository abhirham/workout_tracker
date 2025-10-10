import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_tracker/core/database/app_database.dart';
import 'package:workout_tracker/core/database/database_provider.dart';

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
    final loadedWeeks = await repository.getWeeksForPlan(widget.planId);

    // Load day counts for each week
    final counts = <String, int>{};
    for (final week in loadedWeeks) {
      counts[week.id] = await repository.getDayCountForWeek(week.id);
    }

    setState(() {
      weeks = loadedWeeks;
      dayCounts = counts;
      isLoading = false;
    });
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
    // TODO: Track completed days (requires progress tracking)
    final daysCompleted = 0;
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
