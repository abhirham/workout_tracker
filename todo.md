# Workout Tracking App - Implementation Roadmap

## 📊 CURRENT STATUS

### ✅ COMPLETED (Production Ready)

#### Admin Dashboard (100% Complete)
- ✅ Google OAuth authentication with admin-only access control
- ✅ Protected routes (all pages require admin auth except /login)
- ✅ Admin user management (add/remove admins, invite-only system)
- ✅ Global workouts CRUD (create, read, update, delete with cascade handling)
- ✅ Workout plans CRUD with nested management (Plan → Week → Day → Workout)
- ✅ Fuzzy search autocomplete for workout selection
- ✅ Per-workout configuration (baseWeights, targetReps, rest/workout timers)
- ✅ Alternative workouts suggestions management
- ✅ Bulk edit operations (target reps across weeks)
- ✅ Copy weeks and days functionality
- ✅ Real-time Firestore listeners for live updates
- ✅ Toast notifications for user feedback
- ✅ **JSON Import/Export** (backup/restore plans)
- ✅ Firestore security rules with helper functions
- ✅ Deployed and functional

#### Mobile App - Local Features (95% Complete)
- ✅ Local database with Drift (SQLite) - Schema v8
- ✅ Global workouts library (22 workouts: 21 weight, 1 timer)
- ✅ Workout plan seeding with 8 weeks of progressive overload
- ✅ Navigation flow (Plans → Weeks → Days → Single Exercise View)
- ✅ Weight-based workouts:
  - Weight/reps input with increment controls (+5 lbs, ±1 rep)
  - Progressive overload (+5 lbs per week, phase-boundary aware)
  - Rest timer (45 seconds, auto-start, tap to skip)
  - Preset weights inherited from previous sets
  - Full set tracking with save functionality
- ✅ Timer-based workouts:
  - Countdown timer with live display
  - Start/Stop/Redo controls
  - Auto-save when timer completes
  - Actual duration tracking
- ✅ Workout alternatives system:
  - User-created alternatives (linked to globalWorkoutId)
  - Cross-week/cross-day availability
  - Separate progress tracking per alternative
  - Modal UI for selection
- ✅ Progress tracking with composite keys (planId + weekId + dayId + workoutId)
- ✅ Material 3 UI with Google Fonts
- ✅ Offline-first data storage

#### Firebase Infrastructure (Built but Dormant)
- ✅ Firebase project setup (Firestore, Auth, Security Rules)
- ✅ Template sync service (code ready, not active)
- ✅ Progress sync service (code ready, not active)
- ✅ Sync queue processor (code ready, dormant)
- ✅ Connectivity service (monitoring setup)
- ✅ Firestore security rules (admin dashboard tested)

---

## 🎯 CURRENT PRIORITY: Firebase Auth + Activate Sync (Single-User MVP)

### Phase 1: Authentication & Data Cleanup (Est: 2-3 hours)

#### 1.1 Configure Firebase for Google Sign-In
- [ ] Verify Firebase Console has Google Sign-In enabled
- [ ] Download/update `google-services.json` (Android)
- [ ] Download/update `GoogleService-Info.plist` (iOS)
- [ ] Add OAuth client IDs for iOS/Android in Firebase Console
- [ ] Update `pubspec.yaml` with `google_sign_in` package (if not present)
- [ ] Verify Firebase project ID matches across all config files

#### 1.2 Create Login Screen UI (NO Guest Mode)
- [ ] Create `lib/features/auth/presentation/login_screen.dart`
- [ ] Material 3 design with "Sign in with Google" button
- [ ] Loading state during authentication
- [ ] Error handling with user-friendly messages
- [ ] **NO "Continue as Guest"** - authentication required
- [ ] Show app logo/branding above sign-in button

#### 1.3 Clear Local Testing Data
- [ ] Add migration helper in `lib/core/database/database.dart`
- [ ] Bump schema version (v8 → v9) to trigger clean slate
- [ ] Clear these tables on migration:
  - `completed_sets` (remove temp_user_id data)
  - `workout_plans` (will sync from Firestore)
  - `weeks`, `days`, `workouts`, `set_templates`
  - `workout_alternatives` (user-created, start fresh)
- [ ] Keep `global_workouts` table structure (will sync from Firestore)
- [ ] Show loading screen: "Syncing your workout data from cloud..."

#### 1.4 Update AuthService for Google Sign-In
- [ ] Modify `lib/features/sync/services/auth_service.dart`
- [ ] Replace anonymous auth with Google Sign-In flow
- [ ] Store `userId` in `shared_preferences` after login
- [ ] Provide `getUserId()` method for app-wide access
- [ ] Handle sign-out and re-authentication
- [ ] Error handling (no internet, user cancels, auth errors)
- [ ] **Remove all anonymous auth code**

#### 1.5 Create Auth State Provider
- [ ] Create `lib/features/auth/providers/auth_provider.dart`
- [ ] Riverpod provider to expose current user state
- [ ] Stream changes from Firebase Auth
- [ ] Provide logout method
- [ ] Expose user profile data (name, email, photoURL)
- [ ] Handle auth state: `null` → show login, `User` → show app

#### 1.6 Update Router with Auth Guard
- [ ] Modify `lib/core/router/app_router.dart`
- [ ] Add login route (`/login`)
- [ ] Add redirect logic: unauthenticated → `/login`
- [ ] Authenticated users bypass login screen
- [ ] Persist auth state across app restarts
- [ ] Initial route checks auth state before deciding destination

---

### Phase 2: Replace temp_user_id Everywhere (Est: 1-2 hours)

#### 2.1 Create UserService
- [x] Create `lib/core/services/user_service.dart`
- [x] Central service to get current user ID
- [x] Cache user ID from auth provider
- [x] Fallback to shared_preferences if provider unavailable
- [x] Method: `String getCurrentUserId()`
- [x] Throw error if no user ID available

#### 2.2 Update All Screens (11+ locations)
- [x] `lib/features/workouts/presentation/workout_list_screen.dart` (3 locations replaced)
- [x] `lib/features/workout_plans/presentation/workout_plan_list_screen.dart` (replaced mock data with real data)
- [ ] `lib/features/weeks/presentation/week_selection_screen.dart`
- [ ] `lib/features/days/presentation/day_selection_screen.dart`
- [x] Verified no remaining `const userId = 'temp_user_id'` in codebase
- [x] Replaced with `userService.getCurrentUserIdOrThrow()`
- [ ] Test each screen after update

#### 2.3 Update Repository Methods
- [ ] Pass `userId` from UI to repositories
- [ ] Update database queries to filter by `userId`
- [ ] Ensure all `CompletedSet` inserts include correct `userId`
- [ ] Update `UserProfile` creation with real user data

---

### Phase 3: Activate Firebase Sync (Est: 2-3 hours)

#### 3.1 Verify Sync Services Initialization
- [x] Check `lib/main.dart` - confirm `syncQueueProcessor.start()` called
- [x] Ensure it runs AFTER Firebase initialized and user authenticated
- [x] Add error handling for sync initialization failures
- [x] Only start sync AFTER user is authenticated

#### 3.2 Enable Template Sync (Download from Firestore)
- [x] Activate `syncTemplatesFromFirestore()` in `template_sync_service.dart` (already wired via InitialSyncService)
- [x] Download global workouts from Firestore (replace local seed)
- [x] Download workout plans from Firestore (admin-created plans)
- [x] Handle missing data gracefully (show empty state if no plans)
- [x] Add logging for sync progress
- [x] Show loading screen during initial sync on first login (SyncLoadingScreen)

#### 3.3 Enable Progress Sync (Bidirectional)
- [x] `uploadProgress()` implemented in `progress_sync_service.dart` (via sync queue)
- [x] Progress uploaded via sync queue processor (auto-flush every 60s)
- [ ] Test bidirectional sync (local → Firestore → local)
- [ ] Verify conflict resolution (last-write-wins)
- [ ] Ensure user profile syncs (current plan/week)
- [ ] Test batch uploads (20 sets at a time)

#### 3.4 Add App Lifecycle Hooks
- [x] Modified `lib/main.dart` with WidgetsBindingObserver
- [x] Flush sync queue when app goes to background (`AppLifecycleState.paused`)
- [x] Resume sync when app returns to foreground
- [x] Use `WidgetsBindingObserver` for lifecycle events
- [x] Handle app termination gracefully (detached state)

#### 3.5 Test Offline → Online Transition
- [ ] Enable airplane mode
- [ ] Complete a workout (save sets locally)
- [ ] Disable airplane mode
- [ ] Verify sync queue uploads to Firestore
- [ ] Check admin dashboard shows new completed sets

---

### Phase 4: Sync Status UI (Est: 1-2 hours)

#### 4.1 Create Sync Status Provider
- [ ] Create `lib/features/sync/providers/sync_status_provider.dart`
- [ ] Track sync state: `idle`, `syncing`, `success`, `error`
- [ ] Expose last sync timestamp
- [ ] Expose pending items count
- [ ] Listen to sync queue changes

#### 4.2 Add Sync Indicator to Home Screen
- [ ] Update home/plan list screen
- [ ] Add cloud icon badge showing sync status
- [ ] Show "Synced" / "Syncing..." / "X pending" message
- [ ] Optional: Tap to open sync details modal

#### 4.3 Add Manual Sync Button
- [ ] "Sync Now" button on home screen or app bar
- [ ] Show loading spinner during sync
- [ ] Success toast: "Synced X sets"
- [ ] Error toast with retry option
- [ ] Disable during active sync

#### 4.4 Improve Error Handling
- [ ] Catch sync errors and display to user
- [ ] Add retry button for failed sync items
- [ ] Show specific error messages (no internet, auth expired, etc.)
- [ ] Log errors to console for debugging

---

### Phase 5: Polish Local Features (Est: 2-3 hours)

#### 5.1 Test Core Workout Flow
- [ ] **Weight workouts**: Verify increment controls, save, rest timer
- [ ] **Timer workouts**: Verify countdown, stop, redo
- [ ] **Progressive overload**: Test +5 lbs per week across phase boundaries
- [ ] **Alternatives**: Test create, select, separate tracking
- [ ] Verify all features work with real user IDs

#### 5.2 Fix Any UI Bugs
- [ ] Check spacing, alignment, colors
- [ ] Verify Material 3 theming consistency
- [ ] Test on different screen sizes (Android/iOS)
- [ ] Ensure loading states are clear

#### 5.3 Improve User Feedback
- [ ] Add loading indicators where missing
- [ ] Improve toast messages (clear, actionable)
- [ ] Add confirmation dialogs for destructive actions
- [ ] Ensure all buttons have proper disabled states

#### 5.4 Performance Optimization
- [ ] Profile database queries (should be <16ms)
- [ ] Add database indexes if needed
- [ ] Optimize Riverpod rebuilds with selectors
- [ ] Test with large datasets (100+ completed sets)

---

### Phase 6: Testing & Validation (Est: 2-3 hours)

#### 6.1 End-to-End Testing
- [ ] **Scenario 1**: New user sign-in → download plans → complete workout → verify sync
- [ ] **Scenario 2**: Offline workout → go online → verify sync
- [ ] **Scenario 3**: Sign out → sign in → verify progress persists
- [ ] **Scenario 4**: Admin dashboard → view user's completed sets

#### 6.2 Edge Case Testing
- [ ] No internet connection (graceful degradation)
- [ ] Firebase auth expires (re-prompt login)
- [ ] Sync queue overflow (batch properly)
- [ ] Corrupted local database (reset with warning)
- [ ] Empty plans from Firestore (show helpful empty states)
- [ ] First-time user with no workout plans

#### 6.3 Security Validation
- [ ] Verify Firestore security rules block unauthorized access
- [ ] Test with multiple test accounts (ensure data isolation)
- [ ] Confirm user can only see their own progress
- [ ] Verify admin dashboard respects security rules
- [ ] Test with real user IDs (not temp IDs)

#### 6.4 Performance Validation
- [ ] Measure set save time (should be instant, <16ms)
- [ ] Measure sync upload time (acceptable < 2s for batch)
- [ ] Check memory usage during long workouts
- [ ] Verify no memory leaks
- [ ] Test with 100+ completed sets

---

## 🎯 SUCCESS CRITERIA

### Authentication
- ✅ User can sign in with Google (no guest mode)
- ✅ User ID persists across app restarts
- ✅ Logout works and clears data
- ✅ No anonymous auth code remains

### Data Cleanup
- ✅ No temp_user_id data remains
- ✅ Local database cleared on migration
- ✅ Fresh start with Firestore data

### Sync Active
- ✅ Templates download from Firestore on first launch
- ✅ Completed sets upload to Firestore within 60s
- ✅ Offline → online sync works seamlessly

### Data Isolation
- ✅ User only sees their own progress
- ✅ Firestore security rules enforced
- ✅ Admin dashboard can view all users

### User Experience
- ✅ Sync status visible on home screen
- ✅ Manual sync button works
- ✅ Error messages are clear and actionable

### Production Ready
- ✅ No hardcoded user IDs remaining
- ✅ All TODOs resolved
- ✅ End-to-end flow tested
- ✅ Performance acceptable (<16ms saves)

---

## 📁 FILES TO MODIFY

### New Files
- ✅ `lib/features/auth/presentation/login_screen.dart`
- ✅ `lib/features/sync/presentation/sync_loading_screen.dart`
- ✅ `lib/core/services/user_service.dart`
- ✅ `lib/features/workout_plans/data/workout_plan_repository.dart`
- [ ] `lib/features/sync/providers/sync_status_provider.dart`

### Modified Files
- ✅ `lib/features/sync/services/auth_service.dart` (Google Sign-In implemented)
- ✅ `lib/core/router/app_router.dart` (auth guard, login route, sync route)
- ✅ `lib/main.dart` (lifecycle hooks, sync queue processor startup)
- ✅ `lib/features/workouts/presentation/workout_list_screen.dart` (replaced temp_user_id with UserService)
- ✅ `lib/features/workout_plans/presentation/workout_plan_list_screen.dart` (replaced mock data with real repository)
- ✅ `lib/features/sync/services/initial_sync_service.dart` (template sync activated)
- [ ] `lib/features/weeks/presentation/week_selection_screen.dart` (needs temp_user_id check)
- [ ] `lib/features/days/presentation/day_selection_screen.dart` (needs temp_user_id check)

### Config Files
- `android/app/google-services.json` (update if needed)
- `ios/Runner/GoogleService-Info.plist` (update if needed)
- `pubspec.yaml` (ensure google_sign_in dependency)

---

## ⏱️ ESTIMATED TIMELINE

- **Phase 1** (Auth Setup + Data Cleanup): 2-3 hours
- **Phase 2** (Replace temp IDs): 1-2 hours
- **Phase 3** (Activate Sync): 2-3 hours
- **Phase 4** (Sync UI): 1-2 hours
- **Phase 5** (Polish): 2-3 hours
- **Phase 6** (Testing): 2-3 hours

**Total**: ~10-16 hours (1-2 full work days)

---

## 🚀 FUTURE ENHANCEMENTS (Post-MVP)

### User Features
- [ ] Add exercise video/image attachments
- [ ] Add rest day tracking
- [ ] Add workout history and statistics
- [ ] Add progress charts (weight progression over time)
- [ ] Add workout notes and comments
- [ ] Add personal records (PRs) tracking
- [ ] Add body weight tracking
- [ ] Add workout streaks and achievements

### Admin Dashboard
- [ ] CSV export/import for workout plans
- [ ] Analytics dashboard (completion rates, popular exercises)
- [ ] Activity log (recent user completions)
- [ ] User progress viewer (individual user stats)
- [ ] Workout plan templates library
- [ ] Bulk operations (batch edit multiple plans)

### Technical Improvements
- [ ] Full multi-user support (multiple users per device)
- [ ] Push notifications for rest timer
- [ ] Apple Watch companion app
- [ ] Wear OS support
- [ ] Dark mode
- [ ] Settings screen (timer preferences, units)
- [ ] Onboarding tutorial
- [ ] Error tracking (Sentry/Crashlytics)
- [ ] Performance monitoring
- [ ] Automated testing (unit + integration)

---

## 📚 TECHNICAL STACK

**Mobile App:**
- Flutter 3.x (Dart)
- Riverpod (State Management)
- Drift (Local SQLite Database)
- Firebase (Firestore, Auth)
- GoRouter (Navigation)
- Freezed (Data Classes)
- Google Fonts (Typography)

**Admin Dashboard:**
- React/Next.js
- Firebase (Firestore, Auth, Hosting)
- Tailwind CSS

**Backend:**
- Firebase Firestore (NoSQL Database)
- Firebase Authentication (Google Sign-In)
- Firebase Hosting (Admin Dashboard)

**DevOps:**
- Git for version control
- Firebase CLI for deployment
- Android Studio / Xcode for builds

---

## 📝 NOTES

- **Single-User MVP**: One user per app instance (device-based)
- **No Guest Mode**: Authentication required to use app
- **Data Cleanup**: Migration v8→v9 clears all testing data
- **Sync Strategy**: Offline-first with background sync
- **Admin Ready**: Dashboard already supports multiple users
- **Extensible**: Easy to add full multi-user support later
