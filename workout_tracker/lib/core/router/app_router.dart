import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/features/auth/presentation/login_screen.dart';
import 'package:workout_tracker/features/sync/presentation/sync_loading_screen.dart';
import 'package:workout_tracker/features/sync/services/auth_service.dart';
import 'package:workout_tracker/features/workout_plans/presentation/workout_plan_list_screen.dart';
import 'package:workout_tracker/features/weeks/presentation/week_selection_screen.dart';
import 'package:workout_tracker/features/days/presentation/day_selection_screen.dart';
import 'package:workout_tracker/features/workouts/presentation/workout_list_screen.dart';
import 'package:workout_tracker/features/settings/presentation/settings_screen.dart';
import 'package:workout_tracker/features/gym_card/presentation/gym_card_viewer_screen.dart';

/// Helper class to convert a Stream into a ChangeNotifier for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Router provider that requires ref for auth state
final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) async {
      final user = authService.currentUser;
      final isAuth = user != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSyncing = state.matchedLocation == '/sync';

      // If not authenticated and not on login page, redirect to login
      if (!isAuth && !isLoggingIn) {
        return '/login';
      }

      // If authenticated, check if initial sync is needed
      if (isAuth && !isSyncing) {
        final prefs = await SharedPreferences.getInstance();
        final hasCompletedSync = prefs.getBool('hasCompletedInitialSync') ?? false;

        // If sync not completed and not already on sync page, redirect to sync
        if (!hasCompletedSync && !isSyncing) {
          return '/sync';
        }

        // If on login page and sync completed, redirect to home
        if (isLoggingIn && hasCompletedSync) {
          return '/';
        }
      }

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/sync',
        name: 'sync',
        builder: (context, state) => const SyncLoadingScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const WorkoutPlanListScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/gym-card',
        name: 'gymCard',
        builder: (context, state) => const GymCardViewerScreen(),
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
        final weekNumber = state.uri.queryParameters['weekNumber'] ?? '1';
        return WorkoutListScreen(
          planId: planId,
          weekId: weekId,
          dayId: dayId,
          dayName: dayName,
          weekNumber: int.tryParse(weekNumber) ?? 1,
        );
      },
    ),
    ],
  );
});
