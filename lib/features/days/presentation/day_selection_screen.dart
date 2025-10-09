import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DaySelectionScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Replace with actual data from repository
    final mockDays = [
      {
        'id': 'day_1',
        'dayNumber': 1,
        'name': 'Push Day',
        'workoutCount': 5,
        'completed': false
      },
      {
        'id': 'day_2',
        'dayNumber': 2,
        'name': 'Pull Day',
        'workoutCount': 6,
        'completed': false
      },
      {
        'id': 'day_3',
        'dayNumber': 3,
        'name': 'Leg Day',
        'workoutCount': 4,
        'completed': false
      },
      {
        'id': 'day_4',
        'dayNumber': 4,
        'name': 'Upper Body',
        'workoutCount': 7,
        'completed': false
      },
      {
        'id': 'day_5',
        'dayNumber': 5,
        'name': 'Lower Body',
        'workoutCount': 5,
        'completed': false
      },
      {
        'id': 'day_6',
        'dayNumber': 6,
        'name': 'Full Body',
        'workoutCount': 8,
        'completed': false
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(weekName),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: mockDays.length,
        itemBuilder: (context, index) {
          final day = mockDays[index];
          return _buildDayCard(context, day);
        },
      ),
    );
  }

  Widget _buildDayCard(BuildContext context, Map<String, dynamic> day) {
    final isCompleted = day['completed'] as bool;

    return Card(
      child: InkWell(
        onTap: () {
          context.pushNamed(
            'workouts',
            pathParameters: {
              'planId': planId,
              'weekId': weekId,
              'dayId': day['id'] as String,
            },
            queryParameters: {'dayName': day['name'] as String},
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
                    '${day['dayNumber']}',
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
                day['name'] as String,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${day['workoutCount']} exercises',
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
