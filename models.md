# Firestore Data Models

## Architecture Overview

This document defines the Firestore data structure for the workout tracking app, consisting of:
- **React Admin Dashboard**: Manages workout templates (plans, weeks, days, workouts)
- **Flutter Mobile App**: Syncs templates from Firestore, stores progress locally (Drift), and syncs progress back to Firestore

### Key Design Decisions

1. **Nested Workout Plans**: Workout plans are stored as a single document with nested weeks/days/workouts arrays for simpler admin UI
2. **Separate User Progress**: User progress (completed sets) stored as individual documents in subcollections to avoid 1MB document size limits
3. **Independent Exercise Tracking**: Each exercise (including alternatives) tracks progress independently with separate progressive overload histories
4. **Offline-First Mobile**: Flutter app uses local Drift database, syncs incrementally with Firestore
5. **Single Device, Single Admin**: Simplified conflict resolution (no multi-device sync conflicts, no multi-admin race conditions)

---

## Collection 1: Global Workouts

**Path**: `/global_workouts/list`

**Purpose**: Provide autocomplete list of workout names for admin UI

**Structure**:
```typescript
{
  workouts: string[]  // Array of workout names
}
```

**Example**:
```typescript
{
  workouts: [
    "Bench Press",
    "Squat",
    "Deadlift",
    "Pull-ups",
    "Barbell Row",
    "Overhead Press",
    "Plank",
    "Side Plank",
    // ... ~20-200 workout names
  ]
}
```

**Notes**:
- Single document containing array of workout names
- Used for autocomplete in React admin when adding workouts to plans
- Names should be in Title Case (enforced by admin UI)
- No metadata stored here (type, muscle groups, etc.)

---

## Collection 2: Workout Plans

**Path**: `/workout_plans/{planId}`

**Purpose**: Store workout program templates (admin-managed, synced to mobile users)

**Structure**:
```typescript
{
  id: string;
  name: string;
  description?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  weeks: Week[];
}

interface Week {
  weekNumber: number;
  name: string;
  days: Day[];
}

interface Day {
  dayNumber: number;
  name: string;
  workouts: Workout[];
}

interface Workout {
  globalWorkoutName: string;        // Reference to global workout (e.g., "Bench Press")
  type: 'weight' | 'timer';         // Determines UI rendering in mobile app
  order: number;                    // Display order within the day
  notes?: string;                   // Exercise instructions
  baseWeights: number[] | null;     // Base weights for progressive overload (null for timer workouts)
  targetReps: number | null;        // Target reps for the week (null for timer workouts)
  restTimerSeconds: number | null;  // Rest between sets (45 for weight, null for timer)
  workoutDurationSeconds: number | null;  // Duration for timer workouts (null for weight)
  alternativeWorkouts: string[];    // List of alternative workout names
}
```

**Example**:
```typescript
{
  id: "1",
  name: "Beginner Strength Training",
  description: "8-week progressive overload program",
  createdAt: Timestamp(2025-01-01T00:00:00Z),
  updatedAt: Timestamp(2025-01-01T00:00:00Z),
  weeks: [
    {
      weekNumber: 1,
      name: "Week 1",
      days: [
        {
          dayNumber: 1,
          name: "Chest & Triceps",
          workouts: [
            {
              globalWorkoutName: "Bench Press",
              type: "weight",
              order: 0,
              notes: "Focus on controlled eccentric",
              baseWeights: [10, 10, 10, 10],  // 4 sets, all at 10kg base
              targetReps: 12,  // Week 1 = 12 reps
              restTimerSeconds: 45,
              workoutDurationSeconds: null,
              alternativeWorkouts: ["Dumbbell Press", "Incline Press"]
            },
            {
              globalWorkoutName: "Incline Dumbbell Press",
              type: "weight",
              order: 1,
              notes: "30-45 degree angle",
              baseWeights: [10, 10, 10],  // 3 sets
              targetReps: 12,
              restTimerSeconds: 45,
              workoutDurationSeconds: null,
              alternativeWorkouts: ["Incline Barbell Press"]
            },
            {
              globalWorkoutName: "Plank",
              type: "timer",
              order: 2,
              notes: "Hold steady, no sagging",
              baseWeights: null,
              targetReps: null,
              restTimerSeconds: null,  // No rest timer for timer workouts
              workoutDurationSeconds: 60,  // 60 seconds
              alternativeWorkouts: ["Side Plank"]
            }
          ]
        },
        {
          dayNumber: 2,
          name: "Back & Biceps",
          workouts: [
            // ... more workouts
          ]
        }
      ]
    },
    {
      weekNumber: 2,
      name: "Week 2",
      days: [
        // ... same structure, different targetReps (9 reps for week 2)
      ]
    }
    // ... weeks 3-8
  ]
}
```

**Progressive Overload Formula**:
```
Week cycle (every 4 weeks):
- Week 1: 12 reps
- Week 2: 9 reps
- Week 3: 6 reps
- Week 4: 3 reps
- Week 5: 12 reps (Phase 2)
- ...

Weight progression:
- phase(n+1)week(1) = phase(n)week(1) + 5kg
- phase(n)week(m) = phase(n)week(m-1) + 5kg
```

**Notes**:
- Each plan is a single document (nested structure)
- Document size: ~40KB for 8 weeks × 4 days × 6 workouts (well under 1MB limit)
- Mobile app downloads entire plan on first sync, then checks `updatedAt` for changes
- Admin updates are atomic (entire document is updated via transaction)

---

## Collection 3: Users

**Path**: `/users/{userId}`

**Purpose**: Store user profile metadata (no progress data stored here)

**Structure**:
```typescript
{
  uid: string;              // Firebase Auth UID
  displayName: string;
  email: string;
  role: 'user' | 'admin';
  currentPlanId: string;    // Current workout plan
  currentWeekNumber: number;
  currentDayNumber: number;
  createdAt: Timestamp;
}
```

**Example**:
```typescript
{
  uid: "abc123xyz789",
  displayName: "John Doe",
  email: "john@example.com",
  role: "user",
  currentPlanId: "1",
  currentWeekNumber: 1,
  currentDayNumber: 1,
  createdAt: Timestamp(2025-01-01T00:00:00Z)
}
```

**Notes**:
- User document is created on first login (Firebase Auth trigger or app initialization)
- `role: 'admin'` is set manually in Firestore Console for admin users
- Progress is NOT stored in this document (stored in subcollections instead)

---

## Collection 4: User Progress - Completed Sets

**Path**: `/user_progress/{userId}/completed_sets/{setId}`

**Purpose**: Track individual completed sets (each set is a separate document)

**Structure**:
```typescript
{
  id: string;                    // UUID v4
  userId: string;                // Firebase Auth UID
  planId: string;                // Workout plan ID
  weekNumber: number;
  dayNumber: number;
  workoutName: string;           // Actual exercise performed (e.g., "Bench Press" or "Dumbbell Press")
  setNumber: number;             // Set number within the workout (1, 2, 3, 4)
  weight: number | null;         // Weight in kg (null for timer workouts)
  reps: number | null;           // Reps completed (null for timer workouts)
  duration: number | null;       // Duration in seconds (null for weight workouts)
  completedAt: Timestamp;        // When the set was completed
  syncedAt: Timestamp;           // Server timestamp for conflict resolution
}
```

**Example (Weight Workout)**:
```typescript
{
  id: "uuid-v4-abc123",
  userId: "abc123xyz789",
  planId: "1",
  weekNumber: 1,
  dayNumber: 1,
  workoutName: "Bench Press",
  setNumber: 1,
  weight: 12.5,  // User did 12.5kg (progressed from 10kg base)
  reps: 10,      // User did 10 reps (target was 12)
  duration: null,
  completedAt: Timestamp(2025-01-15T14:30:00Z),
  syncedAt: Timestamp(2025-01-15T14:30:05Z)
}
```

**Example (Timer Workout)**:
```typescript
{
  id: "uuid-v4-def456",
  userId: "abc123xyz789",
  planId: "1",
  weekNumber: 1,
  dayNumber: 1,
  workoutName: "Plank",
  setNumber: 1,
  weight: null,
  reps: null,
  duration: 58,  // User held plank for 58 seconds (target was 60)
  completedAt: Timestamp(2025-01-15T14:35:00Z),
  syncedAt: Timestamp(2025-01-15T14:35:03Z)
}
```

**Example (Using Alternative Exercise)**:
```typescript
{
  id: "uuid-v4-ghi789",
  userId: "abc123xyz789",
  planId: "1",
  weekNumber: 1,
  dayNumber: 1,
  workoutName: "Dumbbell Press",  // User chose alternative instead of "Bench Press"
  setNumber: 1,
  weight: 15,
  reps: 12,
  duration: null,
  completedAt: Timestamp(2025-01-15T14:40:00Z),
  syncedAt: Timestamp(2025-01-15T14:40:04Z)
}
```

**Query Examples**:

```typescript
// Get all sets for Week 1, Day 1
const sets = await getDocs(
  query(
    collection(db, `user_progress/${userId}/completed_sets`),
    where('planId', '==', '1'),
    where('weekNumber', '==', 1),
    where('dayNumber', '==', 1),
    orderBy('completedAt', 'desc')
  )
);

// Get last completed set for "Bench Press" (for progressive overload)
// Note: Each exercise tracks independently, so "Dumbbell Press" has separate history
const lastSet = await getDocs(
  query(
    collection(db, `user_progress/${userId}/completed_sets`),
    where('workoutName', '==', 'Bench Press'),
    where('setNumber', '==', 1),
    orderBy('completedAt', 'desc'),
    limit(1)
  )
);

// Get all sets for Week 1, Day 1, "Bench Press"
const benchPressSets = await getDocs(
  query(
    collection(db, `user_progress/${userId}/completed_sets`),
    where('planId', '==', '1'),
    where('weekNumber', '==', 1),
    where('dayNumber', '==', 1),
    where('workoutName', '==', 'Bench Press'),
    orderBy('setNumber', 'asc')
  )
);
```

**Notes**:
- Each completed set is a separate document (avoids 1MB limit)
- `syncedAt` is set by server timestamp (used for conflict resolution if needed)
- Each exercise tracks independently - "Bench Press" and "Dumbbell Press" have separate progressive overload histories
- `workoutName` stores the actual exercise performed, regardless of what was prescribed in the plan template
- Subcollection path ensures user data isolation

---

## Collection 5: Sync Metadata

**Path**: `/sync_metadata/{userId}`

**Purpose**: Track last sync timestamps to enable incremental sync

**Structure**:
```typescript
{
  userId: string;
  lastTemplateSync: Timestamp;  // Last time workout plans were downloaded
  lastProgressSync: Timestamp;  // Last time progress was synced
}
```

**Example**:
```typescript
{
  userId: "abc123xyz789",
  lastTemplateSync: Timestamp(2025-01-15T12:00:00Z),
  lastProgressSync: Timestamp(2025-01-15T14:30:00Z)
}
```

**Notes**:
- Used by mobile app to determine if templates need re-downloading
- Check `workout_plans.updatedAt > lastTemplateSync` before downloading
- Used for progress sync to upload only new `completed_sets` since last sync

---

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }

    // Helper: Check if user is admin
    function isAdmin() {
      return isAuthenticated() &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Global workouts - read all, write admin only
    match /global_workouts/{document=**} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    // Workout plans - read all, write admin only
    match /workout_plans/{planId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    // User profiles - read own or admin, write own only
    match /users/{userId} {
      allow read: if isAuthenticated() && (request.auth.uid == userId || isAdmin());
      allow create: if isAuthenticated() && request.auth.uid == userId;
      allow update: if isAuthenticated() && request.auth.uid == userId;
      allow delete: if false;  // Never allow deletion via Firestore
    }

    // User progress - user-specific subcollections (read/write own only)
    match /user_progress/{userId}/{document=**} {
      allow read, write: if isAuthenticated() && request.auth.uid == userId;
    }

    // Sync metadata - user-specific
    match /sync_metadata/{userId} {
      allow read, write: if isAuthenticated() && request.auth.uid == userId;
    }
  }
}
```

---

## Firestore Indexes

**Required Composite Indexes**:

```json
{
  "indexes": [
    {
      "collectionGroup": "completed_sets",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "workoutName", "order": "ASCENDING" },
        { "fieldPath": "setNumber", "order": "ASCENDING" },
        { "fieldPath": "completedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "completed_sets",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "planId", "order": "ASCENDING" },
        { "fieldPath": "weekNumber", "order": "ASCENDING" },
        { "fieldPath": "dayNumber", "order": "ASCENDING" },
        { "fieldPath": "completedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "completed_sets",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "planId", "order": "ASCENDING" },
        { "fieldPath": "weekNumber", "order": "ASCENDING" },
        { "fieldPath": "dayNumber", "order": "ASCENDING" },
        { "fieldPath": "workoutName", "order": "ASCENDING" },
        { "fieldPath": "setNumber", "order": "ASCENDING" }
      ]
    }
  ]
}
```

**Note**: Firestore will prompt you to create these indexes when you first run queries that require them.

---

## Data Validation Rules

### Workout Names (Title Case)
- All workout names should be in Title Case: "Bench Press", "Squat", "Deadlift"
- Admin UI should auto-format input to Title Case
- Prevents case-sensitivity issues in Firestore queries

### Workout Type Validation
- `type: 'weight'` → `baseWeights` must be non-null, `workoutDurationSeconds` must be null
- `type: 'timer'` → `baseWeights` must be null, `workoutDurationSeconds` must be non-null

### Progressive Overload Constraints
- `baseWeights` array length determines number of sets
- Each element represents the base weight for that set in Phase 1, Week 1
- Mobile app calculates actual suggested weight using formula

### Completed Sets Constraints
- Weight workouts: `weight` and `reps` must be non-null, `duration` must be null
- Timer workouts: `duration` must be non-null, `weight` and `reps` must be null

---

## Sync Flow

### Template Sync (One-Way: Firestore → Mobile)

1. Mobile app checks `sync_metadata/{userId}.lastTemplateSync`
2. Query `workout_plans` where `updatedAt > lastTemplateSync`
3. Download changed plans (usually just 1 plan)
4. Replace local Drift database with Firestore data
5. Update `lastTemplateSync` to current timestamp

### Progress Sync (Bi-Directional)

**Upload (Mobile → Firestore)**:
1. Mobile app maintains a `sync_queue` table in Drift
2. When user completes a set, save to Drift and add to `sync_queue`
3. When online, iterate through `sync_queue`:
   - Upload each `completed_set` to Firestore subcollection
   - Set `syncedAt` to server timestamp
   - Remove from `sync_queue` on success
4. Update `lastProgressSync` to current timestamp

**Download (Firestore → Mobile)**:
1. Query `completed_sets` where `syncedAt > lastProgressSync`
2. For each remote set:
   - Check if exists locally (by `id`)
   - If not exists: insert into Drift
   - If exists and remote `syncedAt` > local `syncedAt`: update in Drift
3. Update `lastProgressSync` to current timestamp

**Conflict Resolution**:
- Since there's only 1 device per user, conflicts are rare
- If conflict occurs: last-write-wins (compare `syncedAt` timestamps)

---

## TypeScript Type Definitions (React Admin)

```typescript
// src/lib/types/models.ts

export type WorkoutType = 'weight' | 'timer';
export type UserRole = 'user' | 'admin';

export interface GlobalWorkoutsList {
  workouts: string[];
}

export interface WorkoutPlan {
  id: string;
  name: string;
  description?: string;
  createdAt: Date;
  updatedAt: Date;
  weeks: Week[];
}

export interface Week {
  weekNumber: number;
  name: string;
  days: Day[];
}

export interface Day {
  dayNumber: number;
  name: string;
  workouts: Workout[];
}

export interface Workout {
  globalWorkoutName: string;
  type: WorkoutType;
  order: number;
  notes?: string;
  baseWeights: number[] | null;
  targetReps: number | null;
  restTimerSeconds: number | null;
  workoutDurationSeconds: number | null;
  alternativeWorkouts: string[];
}

export interface User {
  uid: string;
  displayName: string;
  email: string;
  role: UserRole;
  currentPlanId: string;
  currentWeekNumber: number;
  currentDayNumber: number;
  createdAt: Date;
}

export interface CompletedSet {
  id: string;
  userId: string;
  planId: string;
  weekNumber: number;
  dayNumber: number;
  workoutName: string;
  setNumber: number;
  weight: number | null;
  reps: number | null;
  duration: number | null;
  completedAt: Date;
  syncedAt: Date;
}

export interface SyncMetadata {
  userId: string;
  lastTemplateSync: Date;
  lastProgressSync: Date;
}
```

---

## Flutter Model Updates Required

### Files to Update:

1. **lib/shared/models/completed_set.dart**
   - Change to use single `workoutName` field (remove dual field approach)
   - Add `syncedAt: DateTime?` field

2. **lib/core/database/app_database.dart**
   - Update `completed_sets` table to use `workoutName` column
   - Add `syncedAt` column to `completed_sets`
   - Remove `workout_alternatives` table (no longer needed)

3. **lib/features/workouts/data/completed_set_repository.dart**
   - Update queries to use `workoutName`
   - Update progressive overload logic to query by actual exercise name
   - Add sync queue logic

4. **Remove lib/features/workouts/data/workout_alternative_repository.dart**
   - No longer needed - alternatives are selected from plan template's `alternativeWorkouts` array

---

## Migration Path

### From Current Local-Only App to Firebase-Synced App:

1. **Phase 1**: Set up Firebase project and Firestore
2. **Phase 2**: Build React admin dashboard
3. **Phase 3**: Seed Firestore with initial workout plan from `database_seeder.dart`
4. **Phase 4**: Update Flutter models to use `globalWorkoutName`
5. **Phase 5**: Implement `SyncService` in Flutter app
6. **Phase 6**: Test sync flow (offline → online, template updates, progress sync)
7. **Phase 7**: Deploy React admin to Firebase Hosting

---

## Document Size Estimates

| Collection | Documents per User | Avg Size per Doc | Total Size |
|------------|-------------------|------------------|------------|
| global_workouts | 1 (shared) | 2KB | 2KB |
| workout_plans | 1 (shared) | 40KB | 40KB |
| users | 1 | 0.5KB | 0.5KB |
| completed_sets | 768 per cycle | 0.2KB | 154KB per cycle |
| sync_metadata | 1 | 0.2KB | 0.2KB |

**Total for 1 user after 1 cycle (8 weeks)**: ~197KB
**Total after 1 year (6 cycles)**: ~967KB ✅ Under 1MB limit
**Total after 2 years (12 cycles)**: ~1.9MB (exceeds if stored in single doc, but we use subcollections)

**Conclusion**: Separate `completed_sets` documents scale indefinitely without hitting limits.

---

## Cost Estimates (Firestore Pricing)

**Assumptions**:
- 100 active users
- Each user syncs daily
- 1 template download per week
- 30 completed sets per day

**Reads**:
- Template sync: 100 users × 1 read/week × 4 weeks = 400 reads/month
- Progress download: 100 users × 1 read/day × 30 days = 3,000 reads/month
- **Total reads**: ~3,400/month

**Writes**:
- Progress upload: 100 users × 30 sets/day × 30 days = 90,000 writes/month
- **Total writes**: ~90,000/month

**Storage**:
- 100 users × 200KB = 20MB

**Cost** (as of 2025):
- Reads: 3,400 × $0.06/100k = $0.002
- Writes: 90,000 × $0.18/100k = $0.16
- Storage: 20MB × $0.18/GB = $0.004
- **Total**: ~$0.17/month

**Note**: First 50k reads, 20k writes, 1GB storage are free daily.

---

## References

- [Firestore Data Model Best Practices](https://firebase.google.com/docs/firestore/data-model)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Flutter Firebase Integration](https://firebase.flutter.dev/)
- [Progressive Overload Formula](./CLAUDE.md#data-architecture)
