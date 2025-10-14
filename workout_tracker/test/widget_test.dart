import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workout_tracker/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: WorkoutTrackerApp()));

    // Verify that the welcome screen appears.
    expect(find.text('Welcome to Workout Tracker'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
