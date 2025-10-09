import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_tracker/features/workout_plans/presentation/workout_plan_list_screen.dart';
import 'package:workout_tracker/features/weeks/presentation/week_selection_screen.dart';
import 'package:workout_tracker/features/days/presentation/day_selection_screen.dart';
import 'package:workout_tracker/features/workouts/presentation/workout_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const WorkoutPlanListScreen(),
    ),
    GoRoute(
      path: '/plan/:planId/weeks',
      name: 'weeks',
      builder: (context, state) {
        final planId = state.pathParameters['planId']!;
        final planName = state.uri.queryParameters['planName'] ?? 'Workout Plan';
        return WeekSelectionScreen(
          planId: planId,
          planName: planName,
        );
      },
    ),
    GoRoute(
      path: '/plan/:planId/week/:weekId/days',
      name: 'days',
      builder: (context, state) {
        final planId = state.pathParameters['planId']!;
        final weekId = state.pathParameters['weekId']!;
        final weekName = state.uri.queryParameters['weekName'] ?? 'Week';
        return DaySelectionScreen(
          planId: planId,
          weekId: weekId,
          weekName: weekName,
        );
      },
    ),
    GoRoute(
      path: '/plan/:planId/week/:weekId/day/:dayId/workouts',
      name: 'workouts',
      builder: (context, state) {
        final planId = state.pathParameters['planId']!;
        final weekId = state.pathParameters['weekId']!;
        final dayId = state.pathParameters['dayId']!;
        final dayName = state.uri.queryParameters['dayName'] ?? 'Day';
        return WorkoutListScreen(
          planId: planId,
          weekId: weekId,
          dayId: dayId,
          dayName: dayName,
        );
      },
    ),
  ],
);
