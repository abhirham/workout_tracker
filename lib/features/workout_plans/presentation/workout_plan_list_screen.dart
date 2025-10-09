import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WorkoutPlanListScreen extends ConsumerWidget {
  const WorkoutPlanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Replace with actual data from repository
    final mockPlans = [
      {'id': '1', 'name': 'Beginner Strength Training', 'weeks': 12},
      {'id': '2', 'name': 'Advanced Powerlifting', 'weeks': 16},
      {'id': '3', 'name': 'Hypertrophy Program', 'weeks': 8},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plans'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              // TODO: Trigger sync
            },
            tooltip: 'Sync',
          ),
        ],
      ),
      body: mockPlans.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mockPlans.length,
              itemBuilder: (context, index) {
                final plan = mockPlans[index];
                return _buildPlanCard(context, plan);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Workout Plans',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to sync plans from admin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              // TODO: Trigger sync
            },
            icon: const Icon(Icons.sync),
            label: const Text('Sync Plans'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, Map<String, dynamic> plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.pushNamed(
            'weeks',
            pathParameters: {'planId': plan['id'] as String},
            queryParameters: {'planName': plan['name'] as String},
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
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['name'] as String,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan['weeks']} weeks',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                  ],
                ),
              ),
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
