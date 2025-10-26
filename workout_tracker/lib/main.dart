import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workout_tracker/core/router/app_router.dart';
import 'package:workout_tracker/features/sync/services/auth_service.dart';
import 'package:workout_tracker/features/sync/services/sync_queue_processor.dart';
import 'package:workout_tracker/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] Successfully initialized');
  } catch (e, stackTrace) {
    debugPrint('[Firebase] Initialization failed: $e');
    debugPrint('[Firebase] Stack trace: $stackTrace');
    // Note: App will continue to run with limited functionality
    // User will see login screen and can still attempt authentication
  }

  // Create provider container
  final container = ProviderContainer();

  // Note: Local seeding removed - all data will be synced from Firestore
  // after user logs in for the first time

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WorkoutTrackerApp(),
    ),
  );
}

class WorkoutTrackerApp extends ConsumerStatefulWidget {
  const WorkoutTrackerApp({super.key});

  @override
  ConsumerState<WorkoutTrackerApp> createState() => _WorkoutTrackerAppState();
}

class _WorkoutTrackerAppState extends ConsumerState<WorkoutTrackerApp> with WidgetsBindingObserver {
  bool _syncProcessorStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSyncProcessor();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!_syncProcessorStarted) return;

    final syncProcessor = ref.read(syncQueueProcessorProvider);

    switch (state) {
      case AppLifecycleState.paused:
        // App going to background - flush sync queue
        debugPrint('[App Lifecycle] App paused, flushing sync queue...');
        syncProcessor.processQueue();
        break;
      case AppLifecycleState.resumed:
        // App returning to foreground - process queue
        debugPrint('[App Lifecycle] App resumed, processing sync queue...');
        syncProcessor.processQueue();
        break;
      case AppLifecycleState.detached:
        // App terminating - final flush attempt
        debugPrint('[App Lifecycle] App detached, final sync flush...');
        syncProcessor.processQueue();
        break;
      default:
        break;
    }
  }

  void _startSyncProcessor() {
    if (_syncProcessorStarted) return;

    debugPrint('[App] Starting sync queue processor...');
    final syncProcessor = ref.read(syncQueueProcessorProvider);
    syncProcessor.start();
    _syncProcessorStarted = true;
  }

  void _stopSyncProcessor() {
    if (!_syncProcessorStarted) return;

    debugPrint('[App] Stopping sync queue processor...');
    final syncProcessor = ref.read(syncQueueProcessorProvider);
    syncProcessor.stop();
    _syncProcessorStarted = false;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Listen to auth state changes and start/stop sync processor
    ref.listen(authStateChangesProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && !_syncProcessorStarted) {
          // User is authenticated, start sync queue processor
          _startSyncProcessor();
        } else if (user == null && _syncProcessorStarted) {
          // User logged out, stop sync processor
          _stopSyncProcessor();
        }
      });
    });

    return MaterialApp.router(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
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
