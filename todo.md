# Workout Tracking App - Todo List

## Phase 1: Project Setup & Architecture

### 1.1 Project Initialization

- [ ] Create Flutter project with `flutter create workout_tracker`
- [ ] Set up Git repository and .gitignore
- [ ] Configure project structure (lib/features, lib/core, lib/shared)
- [ ] Set up environment configuration (.env for Firebase keys)

### 1.2 Firebase Setup

- [ ] Create Firebase project in Firebase Console
- [ ] Enable Firestore Database
- [ ] Enable Firebase Authentication (for multi-user support)
- [ ] Download and configure google-services.json (Android)
- [ ] Download and configure GoogleService-Info.plist (iOS)
- [ ] Add Firebase dependencies to pubspec.yaml
- [ ] Initialize Firebase in main.dart

### 1.3 Local Database & State Management

- [ ] Choose local database (Drift recommended for Flutter + SQL)
- [ ] Add drift, drift_flutter, riverpod dependencies
- [ ] Set up database schema and tables
- [ ] Create DAOs (Data Access Objects)
- [ ] Set up Riverpod providers structure

### 1.4 Project Dependencies

- [ ] Add core dependencies: firebase_core, cloud_firestore, connectivity_plus
- [ ] Add UI dependencies: google_fonts, flutter_animate, go_router
- [ ] Add local storage: drift, shared_preferences
- [ ] Add state management: flutter_riverpod
- [ ] Add utilities: freezed, json_serializable, uuid

---

## Phase 2: Data Models & Architecture

### 2.1 Data Models (Shared Templates)

- [ ] Create WorkoutPlan model (id, name, createdAt, updatedAt) - shared across all users
- [ ] Create Week model (id, planId, weekNumber, name)
- [ ] Create Day model (id, weekId, dayNumber, name)
- [ ] Create Workout model (id, dayId, name, order, notes, defaultSets)
- [ ] Create SetTemplate model (id, workoutId, setNumber, suggestedReps, suggestedWeight)
- [ ] Create TimerConfig model (id, workoutId, duration, isActive)
- [ ] Add Freezed annotations for immutability
- [ ] Generate JSON serialization code

### 2.1.1 Data Models (User Progress)

- [ ] Create UserProfile model (userId, displayName, currentPlanId)
- [ ] Create CompletedSet model (id, userId, workoutId, setNumber, weight, reps, completedAt)
- [ ] Create WorkoutProgress model (userId, workoutId, lastCompletedAt, totalSets)
- [ ] Add Freezed annotations for immutability
- [ ] Generate JSON serialization code

### 2.2 Local Database Schema

**Shared Template Tables:**

- [ ] Create workout_plans table (id, name, createdAt, updatedAt)
- [ ] Create weeks table (id, planId, weekNumber, name)
- [ ] Create days table (id, weekId, dayNumber, name)
- [ ] Create workouts table (id, dayId, name, order, notes, defaultSets)
- [ ] Create set_templates table (id, workoutId, setNumber, suggestedReps, suggestedWeight)
- [ ] Create timer_configs table (id, workoutId, duration, isActive)

**User Progress Tables:**

- [ ] Create user_profile table (userId, displayName, currentPlanId)
- [ ] Create completed_sets table (id, userId, workoutId, setNumber, weight, reps, completedAt)
- [ ] Create workout_progress table (userId, workoutId, lastCompletedAt, totalSets)

**Sync Management:**

- [ ] Create sync_queue table (for pending changes)
- [ ] Add indexes for performance
- [ ] Set up foreign key relationships

### 2.3 Firestore Collection Structure

**Shared Template Collections (read-only for mobile users):**

- [ ] Design /workout_plans collection (id, name, createdAt, updatedAt)
- [ ] Design /workout_plans/{planId}/weeks subcollection
- [ ] Design /workout_plans/{planId}/weeks/{weekId}/days subcollection
- [ ] Design /workout_plans/{planId}/weeks/{weekId}/days/{dayId}/workouts subcollection
- [ ] Design /workout_plans/{planId}/weeks/{weekId}/days/{dayId}/workouts/{workoutId}/set_templates subcollection
- [ ] Design /timer_configs collection (global and per-workout)

**User Progress Collections (per-user, read-write):**

- [ ] Design /user_progress/{userId}/completed_sets collection
- [ ] Design /user_progress/{userId}/workout_progress collection
- [ ] Design /users/{userId} document (profile data)

**Security & Performance:**

- [ ] Create Firestore security rules (templates: read-all, progress: user-specific)
- [ ] Create composite indexes for progress queries
- [ ] Add indexes for filtering by userId and completedAt

### 2.4 Repository Layer

**Template Repositories (read-mostly):**

- [ ] Create WorkoutPlanRepository (local + remote, sync from Firebase)
- [ ] Create WeekRepository
- [ ] Create DayRepository
- [ ] Create WorkoutRepository
- [ ] Create SetTemplateRepository
- [ ] Create TimerConfigRepository

**User Progress Repositories (read-write):**

- [ ] Create UserProgressRepository (local + remote, user-specific)
- [ ] Create CompletedSetRepository (offline-first writes)
- [ ] Create WorkoutProgressRepository

**Sync Management:**

- [ ] Create SyncRepository (handles bidirectional sync)
- [ ] Implement offline-first pattern (read local, write local, sync background)
- [ ] Separate sync logic for templates vs user progress

### 2.5 Sync Service

- [ ] Create SyncService class
- [ ] Implement connectivity listener
- [ ] Implement template sync (download-only, from admin to users)
- [ ] Implement user progress sync (bidirectional, user-specific data)
- [ ] Handle conflict resolution for user progress (last-write-wins with timestamp)
- [ ] Implement retry mechanism with exponential backoff
- [ ] Create sync status provider
- [ ] Add optimistic updates for UI
- [ ] Implement user authentication and userId management

---

## Phase 3: Mobile App - Core Features

### 3.1 Navigation & Routing

- [ ] Set up GoRouter for navigation
- [ ] Create route structure (home → plan → week → day → workouts)
- [ ] Implement deep linking support
- [ ] Add navigation animations

### 3.2 Home Screen - Workout Plans

- [ ] Create WorkoutPlanListScreen
- [ ] Display all workout plans
- [ ] Add "Select Plan" functionality
- [ ] Show current active plan
- [ ] Add search/filter functionality
- [ ] Display sync status indicator

### 3.3 Week Selection Screen

- [ ] Create WeekSelectionScreen
- [ ] Display all weeks for selected plan
- [ ] Show week number and name
- [ ] Add progress indicators (days completed)
- [ ] Navigate to day selection

### 3.4 Day Selection Screen

- [ ] Create DaySelectionScreen
- [ ] Display all days for selected week
- [ ] Show completion status for each day
- [ ] Navigate to workout list

### 3.5 Workout List Screen

- [ ] Create WorkoutListScreen
- [ ] Display all workouts for selected day (from templates)
- [ ] Show workout name and set count
- [ ] Expandable sets view
- [ ] Load user's previous progress for each set (if exists)
- [ ] Weight and reps input fields (optimized for no lag)
- [ ] Checkbox to mark set as complete
- [ ] Auto-save on input change (debounced) to user_progress
- [ ] Show suggested weight/reps from set templates

### 3.6 Set Entry & Management

- [ ] Create SetEntryWidget (weight + reps input)
- [ ] Use TextEditingController with optimized rebuilds
- [ ] Implement local-first saving (instant UI update)
- [ ] Add validation (non-negative numbers)
- [ ] Save to local user_progress DB immediately
- [ ] Queue sync to Firebase user_progress collection
- [ ] Show completion checkmark
- [ ] Pre-fill with user's last completed weight/reps for this set
- [ ] Fall back to template suggestions if no history

### 3.7 Cooldown Timer

- [ ] Create CooldownTimerWidget
- [ ] Fetch timer duration from TimerConfig
- [ ] Countdown timer with circular progress indicator
- [ ] Sound/vibration on completion (optional)
- [ ] Pause/resume functionality
- [ ] Skip timer option
- [ ] Auto-start after set completion
- [ ] Background timer support (keeps running when app is minimized)

### 3.8 Offline Support

- [ ] Implement connectivity detection
- [ ] Show offline indicator in UI
- [ ] Queue all changes locally
- [ ] Sync when connection restored
- [ ] Show pending changes count
- [ ] Handle sync conflicts gracefully

---

## Phase 4: Mobile App - UI/UX Polish

### 4.1 UI Components

- [ ] Create reusable Card components
- [ ] Create reusable Button components
- [ ] Create Input field components (NumberInput)
- [ ] Create Loading states (shimmer effects)
- [ ] Create Empty states
- [ ] Create Error states

### 4.2 Animations & Transitions

- [ ] Add page transition animations
- [ ] Add list item animations (staggered fade-in)
- [ ] Add completion animations (checkmark, confetti)
- [ ] Add progress indicators
- [ ] Add pull-to-refresh

### 4.3 Performance Optimization

- [ ] Use const constructors everywhere
- [ ] Implement ListView.builder for lists
- [ ] Optimize rebuilds with Riverpod selectors
- [ ] Add debouncing for input fields (300ms)
- [ ] Lazy load data
- [ ] Profile app performance

### 4.4 User Experience

- [ ] Add haptic feedback
- [ ] Add success/error snackbars
- [ ] Add confirmation dialogs (delete actions)
- [ ] Implement dark mode
- [ ] Add settings screen
- [ ] Add onboarding/tutorial

---

## Phase 5: Admin Web Dashboard

### 5.1 Dashboard Setup

- [ ] Choose framework (Flutter Web or React/Next.js)
- [ ] Initialize project
- [ ] Set up Firebase integration
- [ ] Set up authentication
- [ ] Create responsive layout

### 5.2 Authentication

- [ ] Create login screen
- [ ] Implement Firebase Authentication
- [ ] Add session management
- [ ] Create protected routes
- [ ] Add logout functionality

### 5.3 Workout Plan Management

- [ ] Create workout plan list view (global templates)
- [ ] Add create workout plan form
- [ ] Add edit workout plan form
- [ ] Add delete workout plan (with confirmation)
- [ ] Add duplicate workout plan feature
- [ ] Add search/filter
- [ ] Note: Plans are global and visible to all users

### 5.4 Week Management

- [ ] Create week management interface (nested under plan)
- [ ] Add create week form
- [ ] Add edit week form
- [ ] Add delete week
- [ ] Add reorder weeks functionality
- [ ] Add bulk week creation (e.g., create 12 weeks at once)

### 5.5 Day Management

- [ ] Create day management interface (nested under week)
- [ ] Add create day form
- [ ] Add edit day form
- [ ] Add delete day
- [ ] Add reorder days functionality
- [ ] Add copy day from previous week

### 5.6 Workout Exercise Management

- [ ] Create workout exercise library (shared templates)
- [ ] Add create exercise form (name, default sets, notes)
- [ ] Add edit exercise
- [ ] Add delete exercise
- [ ] Assign exercises to specific days
- [ ] Add exercise reordering within day
- [ ] Add set template configuration (suggested reps, weight)
- [ ] Note: Exercise templates are global, progress is per-user

### 5.7 Timer Configuration

- [ ] Create timer config screen
- [ ] Add global default timer setting
- [ ] Add per-workout timer override
- [ ] Add enable/disable timer toggle
- [ ] Add timer presets (30s, 60s, 90s, 120s)
- [ ] Save to Firestore

### 5.8 Additional Features

- [ ] Add import/export functionality for workout plans (JSON/CSV)
- [ ] Add workout plan templates library
- [ ] Add analytics dashboard (per-user workout completion rates)
- [ ] Add user management (list all users, view their progress)
- [ ] Add activity log (view recent completions across all users)
- [ ] Add user progress viewer (see individual user's completed sets)

---

## Phase 6: Testing & Quality Assurance

### 6.1 Unit Tests

- [ ] Test data models (serialization/deserialization)
- [ ] Test repository methods
- [ ] Test sync service logic
- [ ] Test timer logic
- [ ] Test validation logic
- [ ] Achieve >80% code coverage

### 6.2 Integration Tests

- [ ] Test offline mode (airplane mode simulation)
- [ ] Test sync after reconnection (templates and user progress)
- [ ] Test conflict resolution for user progress
- [ ] Test data persistence (templates vs user data)
- [ ] Test navigation flow
- [ ] Test multi-user scenario (two users, same plan, separate progress)

### 6.3 Manual Testing

- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test offline → online transition
- [ ] Test data entry performance (should be instant)
- [ ] Test timer functionality
- [ ] Test admin dashboard on desktop browser

### 6.4 Performance Testing

- [ ] Measure app startup time
- [ ] Measure input lag (should be <16ms)
- [ ] Measure sync performance with large datasets
- [ ] Test with 100+ workouts
- [ ] Profile memory usage

---

## Phase 7: Deployment & Documentation

### 7.1 Mobile App Build

- [ ] Configure Android app signing
- [ ] Build Android APK (`flutter build apk`)
- [ ] Build Android App Bundle (optional, for Play Store)
- [ ] Configure iOS provisioning profiles
- [ ] Build iOS IPA (`flutter build ipa`)
- [ ] Test sideloading on physical devices

### 7.2 Admin Dashboard Deployment

- [ ] Build web app for production
- [ ] Deploy to Firebase Hosting (or Vercel/Netlify)
- [ ] Configure custom domain (optional)
- [ ] Set up SSL certificate
- [ ] Test deployed dashboard

### 7.3 Firebase Configuration

- [ ] Finalize Firestore security rules (templates: read-all, user_progress: user-specific)
- [ ] Set up Firestore indexes (especially for user_progress queries)
- [ ] Configure Firebase quotas and limits
- [ ] Set up backup strategy
- [ ] Monitor Firebase usage
- [ ] Ensure users can only read/write their own progress data

### 7.4 Documentation

- [ ] Write README.md with project overview
- [ ] Document sideloading instructions for Android
- [ ] Document sideloading instructions for iOS (TestFlight or direct install)
- [ ] Document admin dashboard usage
- [ ] Create user guide for mobile app
- [ ] Document Firebase setup steps
- [ ] Add architecture diagram

### 7.5 Maintenance & Updates

- [ ] Set up version control strategy
- [ ] Set up error tracking (Sentry/Crashlytics)
- [ ] Monitor app performance
- [ ] Create update/release process

---

## Future Enhancements (Optional)

- [ ] Add exercise video/image attachments
- [ ] Add rest day tracking
- [ ] Add workout history and statistics
- [ ] Add progress charts (weight progression over time)
- [ ] Add workout notes and comments
- [ ] Add personal records (PRs) tracking

---

## Technical Stack Summary

**Mobile App:**

- Flutter (Dart)
- Riverpod (State Management)
- Drift (Local SQLite Database)
- Firebase (Firestore, Auth)
- GoRouter (Navigation)
- Freezed (Data Classes)

**Admin Dashboard:**

- Flutter Web OR React/Next.js
- Firebase (Firestore, Auth, Hosting)
- Tailwind CSS (if React)

**Backend:**

- Firebase Firestore (NoSQL Database)
  - Shared workout templates (plans, weeks, days, workouts, set_templates)
  - User-specific progress data (completed_sets, workout_progress)
- Firebase Authentication (multi-user support)
- Firebase Hosting (Web Dashboard)

**DevOps:**

- Git for version control
- Firebase CLI for deployment
- Android Studio / Xcode for builds
