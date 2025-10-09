# Workout Tracker

An offline-first workout tracking mobile application built with Flutter. Track your workouts, sets, reps, and weight with zero lag, even without internet connection.

## Features

- **Offline-First Architecture**: All data stored locally for instant access and zero-lag input
- **Workout Plans**: Create and follow structured workout plans with weeks, days, and exercises
- **Progress Tracking**: Track your sets, reps, and weight for every exercise
- **Cooldown Timer**: Automatic rest timer between sets with customizable duration
- **Background Sync**: Automatic syncing with Firebase when online
- **Multi-User Support**: Each user's progress is stored separately and securely

## Tech Stack

- **Flutter 3.x** - Cross-platform mobile framework
- **Riverpod** - State management
- **Drift** - Local SQLite database for offline storage
- **Firebase** - Cloud sync and authentication
  - Firestore - NoSQL database
  - Authentication - User management
- **Freezed** - Immutable data models
- **GoRouter** - Navigation
- **Google Fonts** - Typography

## Project Structure

```
lib/
├── core/               # Core utilities and database
│   └── database/       # Drift database setup
├── shared/             # Shared models and widgets
│   └── models/         # Freezed data models
└── features/           # Feature modules
    ├── workout_plans/  # Workout plan management
    ├── weeks/          # Week selection
    ├── days/           # Day selection
    ├── workouts/       # Workout exercises
    ├── progress/       # User progress tracking
    ├── timer/          # Cooldown timer
    └── sync/           # Sync service
```

## Data Architecture

### Two-Tier Model

**1. Shared Templates (Global, Read-Only)**
- WorkoutPlan → Week → Day → Workout → SetTemplate
- Managed by admins via web dashboard
- Synced to all users' local databases

**2. User Progress (Per-User, Read-Write)**
- UserProfile, CompletedSet, WorkoutProgress
- Stored locally and synced to user-specific Firestore collections
- Fully offline-capable with background sync

## Getting Started

### Prerequisites

- Flutter SDK 3.x or higher
- Firebase account
- Android Studio / Xcode (for building on respective platforms)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd workout_tracker
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate code for Freezed and Drift:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. Set up Firebase:
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure
```

5. Run the app:
```bash
flutter run
```

## Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Firestore Database
3. Enable Firebase Authentication
4. Run `flutterfire configure` to generate `firebase_options.dart`
5. Uncomment the Firebase initialization code in `lib/main.dart`

### Firestore Security Rules

```javascript
// Shared workout templates (read-only for users)
match /workout_plans/{planId} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;
}

// User progress (user-specific)
match /user_progress/{userId}/{document=**} {
  allow read, write: if request.auth.uid == userId;
}
```

## Development Commands

```bash
# Run the app
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze

# Generate code (Freezed, Drift, JSON serialization)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
flutter pub run build_runner watch

# Build for release
flutter build apk        # Android
flutter build ipa        # iOS
```

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Building for Production

### Android

```bash
flutter build apk --release
# APK located at: build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ipa --release
# IPA located at: build/ios/ipa/
```

## Performance Considerations

- **Zero Input Lag**: All user input is saved to local database immediately (<16ms)
- **Background Sync**: Changes are synced in the background when online
- **Optimized Rebuilds**: Using Riverpod selectors to minimize unnecessary widget rebuilds
- **Lazy Loading**: Data is loaded on-demand to reduce memory usage

## Architecture Principles

1. **Offline-First**: Always read from and write to local database first
2. **Separate Concerns**: Templates (global) vs Progress (per-user)
3. **Zero Lag**: Never block UI on network calls
4. **Optimistic Updates**: Update UI immediately, sync in background
5. **Conflict Resolution**: Last-write-wins with timestamps

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests and analyzer
4. Create a pull request

## License

This project is private and not licensed for public use.

## Next Steps

- [ ] Implement Firebase authentication
- [ ] Build workout plan list screen
- [ ] Create workout entry UI
- [ ] Implement cooldown timer
- [ ] Build sync service
- [ ] Create admin web dashboard
- [ ] Add progress charts and analytics

For detailed implementation roadmap, see [CLAUDE.md](../CLAUDE.md) and [todo.md](../todo.md).
