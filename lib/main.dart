import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workout_tracker/core/router/app_router.dart';
import 'package:workout_tracker/core/database/database_provider.dart';
import 'package:workout_tracker/firebase_options.dart';
import 'package:workout_tracker/features/sync/services/auth_service.dart';
import 'package:workout_tracker/features/sync/services/sync_queue_processor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Create provider container to access seeder
  final container = ProviderContainer();

  // Seed database with initial data if needed
  try {
    final seeder = container.read(databaseSeederProvider);
    await seeder.seedIfNeeded();
  } catch (e, stackTrace) {
    debugPrint('Error seeding database: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  // Initialize authentication and sync services
  try {
    // Ensure user is authenticated (anonymous auth)
    final authService = container.read(authServiceProvider);
    await authService.ensureAuthenticated();
    debugPrint('User authenticated: ${authService.currentUserId}');

    // Initialize sync queue processor
    final syncProcessor = container.read(syncQueueProcessorProvider);
    syncProcessor.start();

    // Trigger initial full sync in background (non-blocking)
    syncProcessor.fullSync().catchError((e, stackTrace) {
      debugPrint('Error in initial sync: $e');
      debugPrint('Stack trace: $stackTrace');
    });
  } catch (e, stackTrace) {
    debugPrint('Error initializing sync services: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WorkoutTrackerApp(),
    ),
  );
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
    );
  }
}
