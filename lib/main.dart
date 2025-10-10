import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:workout_tracker/core/router/app_router.dart';
import 'package:workout_tracker/core/database/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  // Note: You'll need to add firebase_options.dart using FlutterFire CLI
  // Run: flutterfire configure
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  // Create provider container to access seeder
  final container = ProviderContainer();

  // TEMPORARY: Delete old database to force recreation with new schema
  // Remove this after first successful run
  try {
    final dbPath = await _getDatabasePath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.delete();
      print('🗑️ Deleted old database - will recreate with new schema');
    }
  } catch (e) {
    print('⚠️ Could not delete old database: $e');
  }

  // Seed database with initial data if needed
  try {
    final seeder = container.read(databaseSeederProvider);
    await seeder.seedIfNeeded();
    print('✅ Database seeded successfully');
  } catch (e, stackTrace) {
    print('❌ Error seeding database: $e');
    print('Stack trace: $stackTrace');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WorkoutTrackerApp(),
    ),
  );
}

Future<String> _getDatabasePath() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return p.join(dbFolder.path, 'workout_tracker.sqlite');
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
