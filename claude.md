# Workout Tracking App - Project Context

## Project Overview

A workout tracking application with offline-first mobile app (Flutter) and admin web dashboard for managing workout plans. The app uses a **global workouts library architecture** where workouts are defined globally, plans reference them, and user progress is tracked per-user with composite keys.

## Tech Stack

**Mobile App:**

- Flutter 3.x (Dart)
- State Management: flutter_riverpod
- Local Database: Drift (SQLite)
- Backend: Firebase (Firestore, Auth)
- Navigation: go_router
- Data Classes: freezed + json_serializable
- Utilities: uuid, connectivity_plus

**Admin Dashboard:**

- React/Next.js
- Firebase (Firestore, Auth, Hosting)
- Tailwind CSS

**Backend:**

- Firebase Firestore (NoSQL)
- Firebase Authentication (multi-user)
- Firebase Hosting

## Project Structure

```
lib/
├── core/               # Core utilities, constants, errors
│   ├── database/       # Database setup, seeder, providers
│   └── router/         # Navigation routes
├── shared/             # Shared models, widgets, utilities
│   └── models/         # Freezed data models
├── features/           # Feature-based modules
│   ├── workout_plans/  # Workout plan management
│   ├── weeks/          # Week management
│   ├── days/           # Day management
│   └── workouts/       # Workout exercises & progress
│       ├── data/       # Repositories
│       └── presentation/ # UI screens
└── main.dart
```

## Data Architecture

### Three-Tier Data Model

**1. Global Workouts Library (Shared, Managed by Admins):**

- **GlobalWorkout** (id, name, type, muscleGroups, equipment, searchKeywords, isActive, createdAt, updatedAt)
  - `id`: Unique identifier, URL-safe slug (e.g., "bench-press", "plank")
  - `name`: Display name in Title Case (e.g., "Bench Press", "Plank")
  - `type`: WorkoutType enum ('weight' or 'timer')
  - `muscleGroups`: Array of primary muscle groups (e.g., ["chest", "triceps"])
  - `equipment`: Array of required equipment (e.g., ["barbell", "bench"])
  - `searchKeywords`: Lowercase tokens for autocomplete (e.g., ["bench", "press", "chest"])
  - `isActive`: Boolean flag for soft deletes
  - Managed by admins via web dashboard (currently seeded locally)
  - Synced to all users' local databases

**2. Workout Plan Templates (Shared, Read-Only for Users):**

- **WorkoutPlan** → Week → Day → Workout → SetTemplate
- **Workout** references **GlobalWorkout** via `globalWorkoutId`
- **TimerConfig** (per-workout or global)
- Managed by admins via web dashboard (currently seeded locally)
- Synced to all users' local databases

**Key Workout Identification:**

- Each **Workout** instance has:
  - `id`: Unique per day instance (e.g., "week1_day_1_bench-press")
  - `globalWorkoutId`: References global workout (e.g., "bench-press")
  - `planId`: References workout plan
  - `dayId`: References day
- **WorkoutInstanceId** (generated on-the-fly): planId + weekId + dayId + workoutId
  - Used for progress tracking queries
  - Not stored in database

**3. User Progress (Per-User, Read-Write):**

- **UserProfile** (currentPlanId, settings)
- **CompletedSet** (userId, planId, weekId, dayId, workoutId, setNumber, weight?, reps?, duration?, completedAt, workoutAlternativeId?)
  - Composite tracking: planId + weekId + dayId + workoutId
  - `weight` and `reps`: For weight-based workouts (nullable)
  - `duration`: For timer-based workouts (nullable)
- **WorkoutProgress** (userId, weekId, workoutId, lastCompletedAt, totalSets)
- Stored locally and synced to user-specific Firestore collections (sync not yet implemented)

**4. Workout Alternatives (Per-User):**

- **WorkoutAlternative** (userId, globalWorkoutId, name, createdAt)
- Links to `globalWorkoutId` so alternatives work across all weeks/days
- Example: Create "Dumbbell Press" alternative for "bench-press" (globalWorkoutId), usable in any week

### Firestore Collections

```
/global_workouts/{globalWorkoutId}

/workout_plans/{planId}
  /weeks/{weekId}
    /days/{dayId}
      /workouts/{workoutId}

/users/{userId}
/user_progress/{userId}/completed_sets/{setId}
/user_progress/{userId}/workout_progress/{workoutId}
```

**Key Differences from Local Schema:**

- **Firestore**: Uses normalized subcollections (plan → weeks → days → workouts) for scalability
- **Local DB**: Flattened structure with foreign keys for faster queries
- **Firestore Workouts**: Include template data (`baseWeights`, `targetReps`, `alternativeWorkouts[]`)
- **Firestore Completed Sets**: Use `workoutName` (string) instead of `workoutId` (allows independent tracking of alternatives)
- **User Alternatives**: Only stored locally (not in Firestore templates, which have admin-defined alternatives)

### Local Database (Drift) - Schema v7

**Global Workouts Library:**

- `global_workouts` (id, name, type, muscleGroups, equipment, searchKeywords, isActive, createdAt, updatedAt)
  - `type`: 'weight' or 'timer'
  - `muscleGroups`, `equipment`, `searchKeywords`: JSON arrays stored as TEXT
  - `isActive`: Boolean for soft deletes

**Shared Template Tables:**

- `workout_plans` (id, name, description, totalWeeks, isActive, createdAt, updatedAt)
- `weeks` (id, planId, weekNumber, name, createdAt, updatedAt)
- `days` (id, weekId, dayNumber, name, createdAt, updatedAt)
- `workouts` (id, planId, globalWorkoutId, dayId, name, order, notes, baseWeights, targetReps, restTimerSeconds, workoutDurationSeconds, alternativeWorkouts, createdAt, updatedAt)
  - `id`: Unique per day instance (e.g., "workout-1")
  - `globalWorkoutId`: References global_workouts.id
  - `planId`: References workout_plans.id
  - `baseWeights`: JSON array for progressive overload base (null for timer)
  - `targetReps`: Target reps set by admin per workout (null for timer)
  - `restTimerSeconds`: Rest between sets for weight workouts (null for timer)
  - `workoutDurationSeconds`: Duration for timer workouts (null for weight)
  - `alternativeWorkouts`: JSON array of alternative globalWorkoutIds
- `set_templates` (id, workoutId, setNumber, suggestedReps?, suggestedWeight?, suggestedDuration?)
  - `suggestedDuration`: For timer-based workouts (in seconds)
- `timer_configs` (id, workoutId, durationSeconds, isActive)

**User Progress Tables:**

- `user_profiles` (userId, displayName, email, currentPlanId, currentWeekNumber, currentDayNumber, createdAt, updatedAt, syncLastTemplateSync, syncLastProgressSync)
  - `syncLastTemplateSync`: Timestamp of last template sync from Firestore
  - `syncLastProgressSync`: Timestamp of last progress sync with Firestore
- `completed_sets` (id, userId, planId, weekId, dayId, workoutId, workoutName, setNumber, weight?, reps?, duration?, completedAt, syncedAt, workoutAlternativeId?)
  - Composite tracking: planId + weekId + dayId + workoutId
  - `workoutName`: Actual exercise name performed (for Firestore sync compatibility)
  - `weight`, `reps`: Nullable (for weight workouts)
  - `duration`: Nullable (for timer workouts, in seconds)
  - `syncedAt`: Timestamp when synced to Firestore
- `workout_progress` (userId, weekId, workoutId, lastCompletedAt, totalSets)
  - Primary key: {userId, weekId, workoutId}

**Workout Alternatives Tables:**

- `workout_alternatives` (id, userId, globalWorkoutId, name, createdAt)
  - Links to `globalWorkoutId` for cross-week/cross-day availability
  - User-created alternatives (separate from admin-defined template alternatives)
  - Progress tracked independently per alternative exercise

**Sync Management:**

- `sync_queue` (id, entityType, entityId, operation, data, createdAt, synced)

## Key Features & Requirements

### Mobile App

1. **Offline-First Pattern:**

   - All reads from local database (✅ Implemented)
   - All writes saved locally immediately (✅ Implemented)
   - Background sync when online (🚧 Not yet implemented)
   - Templates sync: download-only (admin → users) (🚧 Currently using local seed data)
   - Progress sync: bidirectional (user-specific) (🚧 Not yet implemented)

2. **Weight-Based Workout Entry:** (✅ Implemented)

   - Display workouts from templates with one exercise at a time
   - Load user's previous progress per set from database
   - Weight/reps input with increment buttons (+/-)
   - Weight inherits from previous set automatically
   - Progressive overload: previous week's weight + 5 lbs
   - Save button (not auto-save) to commit each set
   - Current set is highlighted and editable
   - Completed sets show checkmark icon

3. **Timer-Based Workout Entry:** (✅ Implemented)

   - Display timer workouts (e.g., Plank) with duration targets
   - "Start Timer" button to begin countdown
   - Running timer with live countdown display
   - "Stop & Save" button to end early and save actual duration
   - Auto-save when timer completes
   - "Redo Timer" button for completed sets
   - No progressive overload (fixed duration templates)
   - No rest timer between sets (unlike weight workouts)

4. **Rest Timer (Weight Workouts Only):** (✅ Implemented)

   - Fetch duration from TimerConfig (default: 45 seconds)
   - Auto-start after saving a set (weight workouts only)
   - Tap to skip timer functionality
   - Display at top of screen during countdown
   - Auto-enables next set when timer completes
   - Background support (🚧 Not yet tested)

5. **Workout Alternatives:** (✅ Implemented)

   - **Two types of alternatives:**
     - **Admin-defined**: Stored in workout template's `alternativeWorkouts` array (suggestions)
     - **User-created**: Stored in local `workout_alternatives` table (custom alternatives)
   - User can create alternatives for any workout (e.g., "Dumbbell Press" for "Bench Press")
   - Alternatives are linked by `globalWorkoutId` and work across all weeks/days
   - Alternatives modal shows original workout + admin suggestions + user's custom alternatives
   - Progress is tracked separately per alternative (by `workoutName` in Firestore)
   - Switching alternatives resets to that alternative's progress history

6. **Navigation Flow:** (✅ Implemented)
   - Home (Plan List) → Week Selection → Day Selection → Workout List (one exercise at a time)
   - Previous/Next buttons to navigate between exercises
   - Finish button on last exercise returns to day selection

### Admin Dashboard (✅ Fully Implemented)

1. **Global Workouts Management:** (✅ Implemented)

   - View all global workouts with search and filtering
   - Create new global workouts (name, type: weight/timer, muscle groups, equipment, search keywords)
   - Edit existing global workouts
   - Delete global workouts (with cascade handling - checks for references in workout plans before deletion)
   - Filter by workout type (Weight/Timer) and muscle group
   - Search functionality by workout name
   - Soft delete support (`isActive` flag)

2. **Template Management:** (✅ Implemented)

   - CRUD for WorkoutPlans (references global workouts)
   - Nested management: Plan → Week → Day → Workout
   - Workout selection: Autocomplete dropdown from global workouts library with fuzzy search
   - Configure per workout: `baseWeights`, `targetReps`, `restTimerSeconds`, `workoutDurationSeconds`
   - Set alternative workout suggestions (`alternativeWorkouts[]` array)
   - Timer configuration (per-workout via `restTimerSeconds` and `workoutDurationSeconds`)
   - Bulk operations: Bulk edit target reps across multiple weeks
   - Copy weeks and days functionality
   - Cascade deletion (deletes all nested weeks/days/workouts when plan is deleted)
   - Import/export workout plans (🚧 Not yet implemented)

3. **Admin User Management:** (✅ Implemented)

   - Add/remove admin users (invite-only system)
   - View all admin users with email, creation date, and last login
   - Real-time updates via Firestore listeners
   - Self-protection (admins cannot remove themselves)
   - Note: This is for admin dashboard access only. Regular mobile app users are managed separately and not shown here.

4. **Authentication & Authorization:** (✅ Implemented)
   - Google OAuth login at `/login` page
   - Admin-only access control (verifies `isAdmin: true` in Firestore `users` collection)
   - Protected routes (all pages except `/login` require admin authentication)
   - User info display (name, email, photo from Google account)
   - Sign out functionality with dropdown menu
   - Real-time auth state management
   - Automatic verification on each request via Firestore security rules

### Current Implementation Status

**✅ Fully Implemented:**

**Mobile App:**
- Local database with Drift (SQLite) - Schema v7
- Global workouts library (22 workouts: 21 weight, 1 timer)
- Workout plan seeding with 8 weeks of progressive overload
- Navigation flow (Plans → Weeks → Days → Workouts)
- Single-exercise workout view with set tracking
- Weight-based workouts:
  - Weight/reps input with increment controls
  - Progressive overload (+5 lbs per week)
  - Rest timer (45 seconds, auto-start, skip)
- Timer-based workouts:
  - Duration timer with countdown
  - Start/Stop/Redo controls
  - Actual duration tracking
  - No rest timer between sets
- Workout alternatives system (linked to globalWorkoutId, cross-week availability)
- Progress tracking with composite keys (planId + weekId + dayId + workoutId)
- GlobalWorkoutRepository for CRUD operations
- Updated repositories (CompletedSet, WorkoutAlternative) for new schema

**Admin Dashboard:**
- Google OAuth authentication with admin-only access control
- Protected routes (all pages require admin auth except /login)
- Admin user management (add/remove admins, invite-only system)
- Global workouts CRUD (create, read, update, delete with cascade handling)
- Workout plans CRUD with nested management (Plan → Week → Day → Workout)
- Fuzzy search autocomplete for workout selection
- Per-workout configuration (baseWeights, targetReps, rest/workout timers)
- Alternative workouts suggestions management
- Bulk edit operations (target reps across weeks)
- Copy weeks and days functionality
- Real-time Firestore listeners for live updates
- Toast notifications for user feedback
- Firestore security rules with helper functions

**🚧 In Progress / Not Yet Implemented:**

**Mobile App:**
- Firebase Authentication integration
- Firestore sync (templates and progress)
- Background sync when online
- Multi-user support beyond data structure
- User profile management
- Rest timer background support (not yet tested)

**Admin Dashboard:**
- Import/export workout plans (JSON/CSV)
- Analytics dashboard for user progress viewing
- Activity log for recent user completions

**Current Data Flow:**

1. App launches → Deletes old database (temporary migration helper)
2. Creates fresh database with schema version 7
3. Seeds global workouts library (22 workouts)
4. Seeds 8 weeks of "Beginner Strength Training" plan
5. User navigates: Plan → Week → Day → Workouts
6. User completes sets → Saves to local database immediately
   - Weight workouts: saves weight + reps, starts 45s rest timer
   - Timer workouts: saves duration, moves to next set immediately
7. Progress persists across app restarts

## Code Style & Conventions

- Use Freezed for immutable data models
- Use Riverpod providers for state management
- Prefer const constructors for widgets
- Use ListView.builder for scrollable lists
- Debounce input fields (300ms)
- Add Riverpod selectors to optimize rebuilds
- Use async/await for asynchronous operations
- Follow Flutter/Dart style guide

## Critical Performance Requirements

1. **Zero Input Lag:**

   - Set entry must be instant (<16ms)
   - Save to local DB immediately
   - Queue sync in background
   - Optimistic UI updates

2. **Efficient Sync:**

   - Separate template sync from progress sync
   - Templates: one-way download (admin → users)
   - Progress: bidirectional (user-specific, conflict resolution: last-write-wins)
   - **Batch Writes**: Buffer up to 20 completed sets before writing to Firestore (~95% cost reduction)
   - Auto-flush batch every 60 seconds or on app pause
   - Exponential backoff retry mechanism
   - Connectivity listener

3. **Data Retention:**

   - Keep only last **2 cycles** of progress data (plan-dependent)
   - Example: 8-week plan → 16 weeks retention; 12-week plan → 24 weeks retention
   - Client-side cleanup runs on each sync
   - Batch delete old sets from local DB and Firestore
   - Keeps storage predictable and costs low

4. **Optimize Rebuilds:**
   - Use Riverpod selectors to prevent unnecessary rebuilds
   - Const constructors where possible
   - Lazy loading for large lists

## Firebase Security Rules

Complete Firestore security rules as implemented in `admin-dashboard/firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }

    // Helper function to check if user is an admin
    function isAdmin() {
      return isAuthenticated() &&
             exists(/databases/$(database)/documents/users/$(request.auth.token.email)) &&
             get(/databases/$(database)/documents/users/$(request.auth.token.email)).data.isAdmin == true;
    }

    // Users collection - Admin only access
    match /users/{email} {
      // Only admins can read the users collection
      allow read: if isAdmin();

      // Only admins can create, update, or delete users
      allow create, update, delete: if isAdmin();
    }

    // Global workouts - Read for authenticated, write for admins only
    match /global_workouts/{workoutId} {
      allow read: if isAuthenticated();
      allow create, update, delete: if isAdmin();
    }

    // Workout plans - Read for authenticated, write for admins only
    match /workout_plans/{planId} {
      allow read: if isAuthenticated();
      allow create, update, delete: if isAdmin();

      // Nested collections within workout plans
      match /weeks/{weekId} {
        allow read: if isAuthenticated();
        allow create, update, delete: if isAdmin();

        match /days/{dayId} {
          allow read: if isAuthenticated();
          allow create, update, delete: if isAdmin();

          match /workouts/{workoutId} {
            allow read: if isAuthenticated();
            allow create, update, delete: if isAdmin();
          }
        }
      }
    }

    // User progress - User-specific read/write access
    // (For mobile app users - not used in admin dashboard)
    match /user_progress/{userId}/{document=**} {
      allow read, write: if isAuthenticated() && request.auth.uid == userId;
    }

    // Deny all other access by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Development Commands

```bash
# Flutter
flutter create workout_tracker
flutter run
flutter build apk
flutter build ipa
flutter test

# Firebase
firebase init
firebase deploy
firebase emulators:start

# Code Generation (Freezed, JSON Serialization, Drift)
flutter pub run build_runner build --delete-conflicting-outputs
```

## Do Not

- Do not expose user progress data across users (strict user-specific access)
- Do not allow mobile users to modify global workout templates
- Do not allow non-admin users to access the admin dashboard
- Do not skip admin verification checks (always verify isAdmin flag in Firestore)
- Do not allow admins to remove themselves from the users collection
- Do not skip offline-first pattern (always write locally first)
- Do not introduce input lag (no network calls on text input)
- Do not use force push to main/master branch
- Do not commit sensitive files (.env, credentials, Firebase config)

## Testing Strategy

1. **Unit Tests:**

   - Data model serialization
   - Repository methods
   - Sync logic
   - Timer logic (both rest timer and workout timer)
   - Progressive overload calculations
   - Target: >80% coverage

2. **Integration Tests:**

   - Offline mode (airplane mode simulation)
   - Sync after reconnection
   - Conflict resolution
   - Multi-user scenarios (two users, same plan, separate progress)
   - Weight vs timer workout flows

3. **Manual Testing:**
   - Test on Android and iOS devices
   - Offline → online transition
   - Input lag verification (<16ms)
   - Rest timer background functionality
   - Workout timer functionality (start, stop, auto-save)
   - Progressive overload accuracy
   - Alternatives switching

## Deployment

**Mobile App:**

- Sideload only (no app stores initially)
- Android APK signing
- iOS provisioning profiles
- TestFlight for iOS testing

**Admin Dashboard:**

- Next.js application deployed to Firebase Hosting (or Vercel/Netlify)
- Production build: `npm run build` in admin-dashboard directory
- Environment variables: Firebase config in `.env.local` (do not commit)
- Firebase project: `bodyfit-b1563`
- Requires admin users to be added to Firestore `/users` collection before login
- SSL certificate (automatic with Firebase Hosting)
- Custom domain (optional)
- Google OAuth enabled in Firebase Console Authentication settings

## Version Control

- Use Git for version control
- Branch format: `feature/description` or `bugfix/description`
- Commit format: Conventional Commits
- No direct commits to main
- Create pull requests for code review

## Progressive Overload Rules

### Weight Progression (Automatic)

Rules for starting weights for sets (grouping every 4 weeks into 1 phase):

- **phase(n+1)week(1)** weight = **phase(n)week(1) + 5**
- **phase(n)week(m)** weight = **phase(n)week(m-1) + 5** (where m > 1)

**Example:**

- Week 1: 10 lbs (base)
- Week 2: 15 lbs (Week 1 + 5)
- Week 3: 20 lbs (Week 2 + 5)
- Week 4: 25 lbs (Week 3 + 5)
- Week 5 (Phase 2): 15 lbs (Week 1 + 5)
- Week 6: 20 lbs (Week 5 + 5)
- etc.

### Rep Targets (Admin-Configured)

- **Target reps are set manually by the admin** when creating the workout template
- Each workout can have different target reps per week (e.g., Week 1: 12 reps, Week 2: 9 reps, Week 3: 6 reps, Week 4: 3 reps)
- No automatic rep progression - fully configurable per workout instance
- Allows admin to design custom periodization schemes

**Note:** Progressive overload only applies to weight-based workouts. Timer-based workouts use fixed duration templates.

## Quick Visual Check

IMMEDIATELY after implementing any front-end change in admin-dashboard:

1. **Identify what changed** – Review the modified components/pages
2. **Navigate to affected pages** – Use `mcp__playwright__browser_navigate` to visit each changed view
3. **Always reference**: `admin-dashboard/context/style-guide.md` for visual styling, colors, typography, and component patterns
4. **Validate feature implementation** – Ensure the change fulfills the user's specific request
5. **Check acceptance criteria** – Review any provided context files or requirements
6. **Compare against design mockups** – Reference the design files below to ensure UI matches:
   - **Global Workouts page** → `admin-dashboard/context/designs/workouts page.png`
   - **Users page** → `admin-dashboard/context/designs/users page.png`
   - **Workout Plans page** → `admin-dashboard/context/designs/plans_page.png`
   - **Add/Edit Plan page** → `admin-dashboard/context/designs/addPlan.png`
   - **Add New Workout modal** → `admin-dashboard/context/designs/add new workout.png`
   - **Add Existing Workout modal** → `admin-dashboard/context/designs/add existing workout.png`
   - **Search Existing Workout UI** → `admin-dashboard/context/designs/searchExistingWorkout.png`
7. **Capture evidence** – Take full page screenshot at desktop viewport (1440px) of each changed view
8. **Check for errors** – Run `mcp__playwright__browser_console_messages`

## References

- Flutter documentation: https://flutter.dev
- Firebase documentation: https://firebase.google.com/docs
- Riverpod documentation: https://riverpod.dev
- Drift documentation: https://drift.simonbinder.eu
- always run 'npm run dev' on port 3001. Kill any processes running on 3001 and strictly use only that.
