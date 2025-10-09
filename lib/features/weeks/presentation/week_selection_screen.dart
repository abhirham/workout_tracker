import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WeekSelectionScreen extends ConsumerWidget {
  final String planId;
  final String planName;

  const WeekSelectionScreen({
    super.key,
    required this.planId,
    required this.planName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Replace with actual data from repository
    final mockWeeks = List.generate(
      12,
      (index) => {
        'id': 'week_${index + 1}',
        'weekNumber': index + 1,
        'name': 'Week ${index + 1}',
        'daysCompleted': (index % 3) * 2, // Mock progress
        'totalDays': 6,
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(planName),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockWeeks.length,
        itemBuilder: (context, index) {
          final week = mockWeeks[index];
          return _buildWeekCard(context, week);
        },
      ),
    );
  }

  Widget _buildWeekCard(BuildContext context, Map<String, dynamic> week) {
    final daysCompleted = week['daysCompleted'] as int;
    final totalDays = week['totalDays'] as int;
    final progress = totalDays > 0 ? daysCompleted / totalDays : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.pushNamed(
            'days',
            pathParameters: {
              'planId': planId,
              'weekId': week['id'] as String,
            },
            queryParameters: {'weekName': week['name'] as String},
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
                    'W${week['weekNumber']}',
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
                      week['name'] as String,
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
