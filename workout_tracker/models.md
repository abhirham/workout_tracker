# Firestore Data Models

## Architecture Overview

This document defines the Firestore data structure for the workout tracking app, consisting of:

- **React Admin Dashboard**: Manages workout templates (plans, weeks, days, workouts)
- **Flutter Mobile App**: Syncs templates from Firestore, stores progress locally (Drift), and syncs progress back to Firestore

### Key Design Decisions

1. **Normalized Collections**: Global workouts, workout plans, weeks, and days are stored as separate collections/subcollections for scalability and partial updates
2. **Separate User Progress**: User progress (completed sets) stored as individual documents in subcollections to avoid 1MB document size limits
3. **Independent Exercise Tracking**: Each exercise (including alternatives) tracks progress independently with separate progressive overload histories
4. **Offline-First Mobile**: Flutter app uses local Drift database, syncs incrementally with Firestore
5. **Single Device, Single Admin**: Simplified conflict resolution (no multi-device sync conflicts, no multi-admin race conditions)
6. **Data Retention**: Client-side cleanup keeps only last 2 cycles (16 weeks) of progress data
7. **Batch Writes**: Progress syncs in batches of 20 sets to reduce costs by ~95%
8. **Custom Claims**: Admin role stored in Firebase Auth JWT (not Firestore) to avoid extra reads

---

## Collection 1: Global Workouts

**Path**: `/global_workouts/{workoutId}`

**Purpose**: Master library of all available exercises with metadata for autocomplete, filtering, and categorization

**Structure**:

```typescript
{
  id: string;                   // URL-safe slug (e.g., "bench-press")
  name: string;                 // Display name in Title Case (e.g., "Bench Press")
  type: 'weight' | 'timer';     // Workout type
  muscleGroups: string[];       // Primary muscles (e.g., ["chest", "triceps"])
  equipment: string[];          // Required equipment (e.g., ["barbell", "bench"])
  searchKeywords: string[];     // Lowercase tokens for autocomplete (e.g., ["bench", "press", "chest"])
  createdAt: Timestamp;
  updatedAt: Timestamp;
  isActive: boolean;            // Soft delete flag
}
```

**Example**:

```typescript
{
  id: "bench-press",
  name: "Bench Press",
  type: "weight",
  muscleGroups: ["chest", "triceps", "shoulders"],
  equipment: ["barbell", "bench"],
  searchKeywords: ["bench", "press", "chest", "barbell"],
  createdAt: Timestamp(2025-01-01T00:00:00Z),
  updatedAt: Timestamp(2025-01-01T00:00:00Z),
  isActive: true
}
```

**Query Examples**:

```typescript
// Autocomplete search
const workouts = await getDocs(
  query(
    collection(db, "global_workouts"),
    where("searchKeywords", "array-contains", "ben"),
    where("isActive", "==", true),
    orderBy("name", "asc"),
    limit(10)
  )
);

// Filter by muscle group
const chestWorkouts = await getDocs(
  query(
    collection(db, "global_workouts"),
    where("muscleGroups", "array-contains", "chest"),
    where("isActive", "==", true)
  )
);

// Get all weight-based workouts
const weightWorkouts = await getDocs(
  query(
    collection(db, "global_workouts"),
    where("type", "==", "weight"),
    where("isActive", "==", true),
    orderBy("name", "asc")
  )
);
```

**Notes**:

- Each workout is a separate document (atomic updates)
- `searchKeywords` array enables efficient autocomplete via `array-contains`
- `isActive` flag for soft deletes (never hard delete if used in plans)
- Names must be in Title Case (enforced by admin UI)
- `id` should be URL-safe slug generated from name (e.g., "Bench Press" → "bench-press")

---

## Collection 2: Workout Plans

**Path**: `/workout_plans/{planId}`

**Purpose**: Store workout program metadata (plan header only, weeks/days stored in subcollections)

**Structure**:

```typescript
{
  id: string;
  name: string;
  description?: string;
  totalWeeks: number;               // Total number of weeks in the plan
  createdAt: Timestamp;
  updatedAt: Timestamp;
  isActive: boolean;                // Soft delete flag
}
```

**Subcollection: Weeks**

**Path**: `/workout_plans/{planId}/weeks/{weekId}`

**Structure**:

```typescript
{
  id: string; // e.g., "week-1"
  weekNumber: number; // 1, 2, 3, etc.
  name: string; // e.g., "Week 1"
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Subcollection: Days**

**Path**: `/workout_plans/{planId}/weeks/{weekId}/days/{dayId}`

**Structure**:

```typescript
{
  id: string; // e.g., "day-1"
  dayNumber: number; // 1, 2, 3, etc.
  name: string; // e.g., "Chest & Triceps"
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Subcollection: Workouts**

**Path**: `/workout_plans/{planId}/weeks/{weekId}/days/{dayId}/workouts/{workoutId}`

**Structure**:

```typescript
{
  id: string;                       // e.g., "workout-1"
  globalWorkoutId: string;          // Reference to global_workouts.id (e.g., "bench-press")
  globalWorkoutName: string;        // Denormalized for display (e.g., "Bench Press")
  type: 'weight' | 'timer';         // Denormalized from global workout
  order: number;                    // Display order within the day (0, 1, 2...)
  notes?: string;                   // Exercise instructions
  baseWeights: number[] | null;     // Base weights for progressive overload (null for timer)
  targetReps: number | null;        // Target reps for this workout (null for timer)
  restTimerSeconds: number | null;  // Rest between sets (45 for weight, null for timer)
  workoutDurationSeconds: number | null;  // Duration for timer workouts (null for weight)
  alternativeWorkouts: string[];    // List of alternative workout IDs (e.g., ["dumbbell-press"])
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Example Hierarchy**:

```
/workout_plans/beginner-strength
  {
    id: "beginner-strength",
    name: "Beginner Strength Training",
    description: "8-week progressive overload program",
    totalWeeks: 8,
    createdAt: Timestamp(2025-01-01T00:00:00Z),
    updatedAt: Timestamp(2025-01-01T00:00:00Z),
    isActive: true
  }

  /weeks/week-1
    {
      id: "week-1",
      weekNumber: 1,
      name: "Week 1",
      createdAt: Timestamp(2025-01-01T00:00:00Z),
      updatedAt: Timestamp(2025-01-01T00:00:00Z)
    }

    /days/day-1
      {
        id: "day-1",
        dayNumber: 1,
        name: "Chest & Triceps",
        createdAt: Timestamp(2025-01-01T00:00:00Z),
        updatedAt: Timestamp(2025-01-01T00:00:00Z)
      }

      /workouts/workout-1
        {
          id: "workout-1",
          globalWorkoutId: "bench-press",
          globalWorkoutName: "Bench Press",
          type: "weight",
          order: 0,
          notes: "Focus on controlled eccentric",
          baseWeights: [10, 10, 10, 10],  // 4 sets
          targetReps: 12,  // Week 1 target
          restTimerSeconds: 45,
          workoutDurationSeconds: null,
          alternativeWorkouts: ["dumbbell-press", "incline-press"],
          createdAt: Timestamp(2025-01-01T00:00:00Z),
          updatedAt: Timestamp(2025-01-01T00:00:00Z)
        }

      /workouts/workout-2
        {
          id: "workout-2",
          globalWorkoutId: "plank",
          globalWorkoutName: "Plank",
          type: "timer",
          order: 1,
          notes: "Hold steady, no sagging",
          baseWeights: null,
          targetReps: null,
          restTimerSeconds: null,
          workoutDurationSeconds: 60,
          alternativeWorkouts: ["side-plank"],
          createdAt: Timestamp(2025-01-01T00:00:00Z),
          updatedAt: Timestamp(2025-01-01T00:00:00Z)
        }

    /days/day-2
      { ... }

  /weeks/week-2
    {
      id: "week-2",
      weekNumber: 2,
      name: "Week 2",
      createdAt: Timestamp(2025-01-01T00:00:00Z),
      updatedAt: Timestamp(2025-01-01T00:00:00Z)
    }
    /days/...
      /workouts/workout-1
        {
          ...
          targetReps: 9,  // Week 2 target (different from Week 1)
          ...
        }
```

**Query Examples**:

```typescript
// Get plan metadata
const plan = await getDoc(doc(db, "workout_plans", "beginner-strength"));

// Get all weeks for a plan
const weeks = await getDocs(
  query(
    collection(db, "workout_plans/beginner-strength/weeks"),
    orderBy("weekNumber", "asc")
  )
);

// Get all days for Week 1
const days = await getDocs(
  query(
    collection(db, "workout_plans/beginner-strength/weeks/week-1/days"),
    orderBy("dayNumber", "asc")
  )
);

// Get all workouts for Day 1
const workouts = await getDocs(
  query(
    collection(
      db,
      "workout_plans/beginner-strength/weeks/week-1/days/day-1/workouts"
    ),
    orderBy("order", "asc")
  )
);
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

- Normalized subcollection structure (plan → weeks → days → workouts)
- Enables partial updates (e.g., update Week 1 without touching Week 2)
- Scales to 52+ week programs without hitting 1MB limits
- Mobile app can cache only current week (reduces bandwidth/storage)
- Each subcollection document is independently updated (no monolithic writes)
- `targetReps` set per workout (allows flexibility - different exercises can have different rep targets in same week)
- `globalWorkoutId` is the source of truth, `globalWorkoutName` is denormalized for display

---

## Collection 3: Users

**Path**: `/users/{userId}`

**Purpose**: Store user profile metadata and sync timestamps

**Structure**:

```typescript
{
  uid: string; // Firebase Auth UID (redundant with doc ID, but useful)
  displayName: string;
  email: string;
  currentPlanId: string; // Current workout plan
  currentWeekNumber: number;
  currentDayNumber: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  sync: {
    // Embedded sync metadata
    lastTemplateSync: Timestamp; // Last time workout plans were downloaded
    lastProgressSync: Timestamp; // Last time progress was synced
  }
}
```

**Example**:

```typescript
{
  uid: "abc123xyz789",
  displayName: "John Doe",
  email: "john@example.com",
  currentPlanId: "beginner-strength",
  currentWeekNumber: 1,
  currentDayNumber: 1,
  createdAt: Timestamp(2025-01-01T00:00:00Z),
  updatedAt: Timestamp(2025-01-15T14:30:00Z),
  sync: {
    lastTemplateSync: Timestamp(2025-01-15T12:00:00Z),
    lastProgressSync: Timestamp(2025-01-15T14:30:00Z)
  }
}
```

**Notes**:

- User document is created on first login (Firebase Auth trigger or app initialization)
- Admin role is stored in Firebase Auth custom claims (NOT in this document)
- Progress is NOT stored in this document (stored in subcollections)
- Sync metadata embedded here (no separate collection) for atomic reads

---

## Collection 4: User Progress - Completed Sets

**Path**: `/user_progress/{userId}/completed_sets/{setId}`

**Purpose**: Track individual completed sets (each set is a separate document)

**Structure**:

```typescript
{
  id: string; // UUID v4
  // userId removed - redundant (already in path /user_progress/{userId}/)
  planId: string; // Workout plan ID
  weekNumber: number;
  dayNumber: number;
  workoutName: string; // Actual exercise performed (e.g., "Bench Press" or "Dumbbell Press")
  setNumber: number; // Set number within the workout (1, 2, 3, 4)
  weight: number | null; // Weight in kg (null for timer workouts)
  reps: number | null; // Reps completed (null for timer workouts)
  duration: number | null; // Duration in seconds (null for weight workouts)
  completedAt: Timestamp; // When the set was completed
  syncedAt: Timestamp; // Server timestamp for sync tracking
}
```

**Example (Weight Workout)**:

```typescript
{
  id: "uuid-v4-abc123",
  planId: "beginner-strength",
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
  planId: "beginner-strength",
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
  planId: "beginner-strength",
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
    where("planId", "==", "1"),
    where("weekNumber", "==", 1),
    where("dayNumber", "==", 1),
    orderBy("completedAt", "desc")
  )
);

// Get last completed set for "Bench Press" (for progressive overload)
// Note: Each exercise tracks independently, so "Dumbbell Press" has separate history
const lastSet = await getDocs(
  query(
    collection(db, `user_progress/${userId}/completed_sets`),
    where("workoutName", "==", "Bench Press"),
    where("setNumber", "==", 1),
    orderBy("completedAt", "desc"),
    limit(1)
  )
);

// Get all sets for Week 1, Day 1, "Bench Press"
const benchPressSets = await getDocs(
  query(
    collection(db, `user_progress/${userId}/completed_sets`),
    where("planId", "==", "1"),
    where("weekNumber", "==", 1),
    where("dayNumber", "==", 1),
    where("workoutName", "==", "Bench Press"),
    orderBy("setNumber", "asc")
  )
);
```

**Notes**:

- Each completed set is a separate document (avoids 1MB limit)
- `userId` removed from document (redundant - already in subcollection path)
- `syncedAt` is set by server timestamp (used for incremental sync)
- Each exercise tracks independently - "Bench Press" and "Dumbbell Press" have separate progressive overload histories
- `workoutName` stores the actual exercise performed, regardless of what was prescribed in the plan template
- Subcollection path ensures user data isolation
- **Data Retention**: Client-side cleanup deletes sets older than 2 cycles (plan-dependent duration)
- **Batch Writes**: Mobile app batches 20 sets per Firestore write to reduce costs by ~95%

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

    // Helper: Check if user is admin (uses custom claims, NOT Firestore read)
    function isAdmin() {
      return isAuthenticated() && request.auth.token.admin == true;
    }

    // Global workouts - read all, write admin only
    match /global_workouts/{workoutId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }

    // Workout plans - read all, write admin only
    match /workout_plans/{planId} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();

      // Weeks subcollection
      match /weeks/{weekId} {
        allow read: if isAuthenticated();
        allow write: if isAdmin();

        // Days subcollection
        match /days/{dayId} {
          allow read: if isAuthenticated();
          allow write: if isAdmin();

          // Workouts subcollection
          match /workouts/{workoutId} {
            allow read: if isAuthenticated();
            allow write: if isAdmin();
          }
        }
      }
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
  }
}
```

**Setting Admin Custom Claims (Admin SDK)**:

```typescript
// Run this server-side or via Firebase CLI
import * as admin from "firebase-admin";

await admin.auth().setCustomUserClaims(userId, { admin: true });

// Force token refresh on client
await auth.currentUser?.getIdToken(true);
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
    },
    {
      "collectionGroup": "completed_sets",
      "queryScope": "COLLECTION",
      "fields": [{ "fieldPath": "syncedAt", "order": "DESCENDING" }]
    },
    {
      "collectionGroup": "global_workouts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isActive", "order": "ASCENDING" },
        { "fieldPath": "name", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "global_workouts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "searchKeywords", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "workouts",
      "queryScope": "COLLECTION",
      "fields": [{ "fieldPath": "order", "order": "ASCENDING" }]
    }
  ]
}
```

**Note**: Firestore will auto-prompt you to create these indexes when you first run queries. You can also deploy via `firebase deploy --only firestore:indexes`.

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

1. Mobile app checks `users/{userId}.sync.lastTemplateSync`
2. Query `workout_plans` where `updatedAt > lastTemplateSync`
3. For each changed plan:
   - Download plan metadata
   - Download all weeks subcollection
   - Download all days for each week
   - Download all workouts for each day
4. Replace local Drift database with Firestore data
5. Update `users/{userId}.sync.lastTemplateSync` to current timestamp

**Optimization**: Only sync current week initially, lazy-load other weeks on demand.

### Progress Sync (Bi-Directional)

**Upload (Mobile → Firestore) - BATCHED**:

1. Mobile app buffers completed sets in memory (max 20 sets)
2. When buffer reaches 20 sets OR 60 seconds elapsed OR app pauses:
   - Batch write all pending sets to Firestore in single transaction
   - Set `syncedAt` to server timestamp
   - Clear buffer on success
3. Update `users/{userId}.sync.lastProgressSync` to current timestamp
4. Run cleanup: delete local/remote sets older than 2 cycles

**Download (Firestore → Mobile)**:

1. Query `completed_sets` where `syncedAt > lastProgressSync`
2. For each remote set:
   - Check if exists locally (by `id`)
   - If not exists: insert into Drift
   - If exists and remote `syncedAt` > local `syncedAt`: update in Drift
3. Update `users/{userId}.sync.lastProgressSync` to current timestamp

**Conflict Resolution**:

- Since there's only 1 device per user, conflicts are rare
- If conflict occurs: last-write-wins (compare `syncedAt` timestamps)

**Data Retention (Client-Side Cleanup)**:

1. Calculate retention window based on plan duration: `2 cycles = 2 × plan.totalWeeks × 7 days`
2. On each sync, delete local completed_sets where `completedAt < now - retention_window`
3. Batch delete remote completed_sets where `completedAt < now - retention_window`
4. Example: 8-week plan → 16 weeks retention; 12-week plan → 24 weeks retention
5. Keeps storage predictable

---

## TypeScript Type Definitions (React Admin)

```typescript
// src/lib/types/models.ts

export type WorkoutType = "weight" | "timer";

export interface GlobalWorkout {
  id: string;
  name: string;
  type: WorkoutType;
  muscleGroups: string[];
  equipment: string[];
  searchKeywords: string[];
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
}

export interface WorkoutPlan {
  id: string;
  name: string;
  description?: string;
  totalWeeks: number;
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
}

export interface Week {
  id: string;
  weekNumber: number;
  name: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface Day {
  id: string;
  dayNumber: number;
  name: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface Workout {
  id: string;
  globalWorkoutId: string;
  globalWorkoutName: string;
  type: WorkoutType;
  order: number;
  notes?: string;
  baseWeights: number[] | null;
  targetReps: number | null;
  restTimerSeconds: number | null;
  workoutDurationSeconds: number | null;
  alternativeWorkouts: string[];
  createdAt: Date;
  updatedAt: Date;
}

export interface User {
  uid: string;
  displayName: string;
  email: string;
  currentPlanId: string;
  currentWeekNumber: number;
  currentDayNumber: number;
  createdAt: Date;
  updatedAt: Date;
  sync: {
    lastTemplateSync: Date;
    lastProgressSync: Date;
  };
}

export interface CompletedSet {
  id: string;
  // userId removed - derived from subcollection path
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
```

---

## Flutter Model Updates Required

### Major Changes from Current Local-Only Schema:

1. **Global Workouts**: Add metadata fields

   - `muscleGroups: List<String>`
   - `equipment: List<String>`
   - `searchKeywords: List<String>`
   - `isActive: bool`

2. **Workout Plans**: Normalize to separate tables

   - Move `weeks` from nested array to `weeks` table with `planId` foreign key
   - Move `days` from nested array to `days` table with `weekId` foreign key
   - Move `workouts` from nested array to `workouts` table with `dayId` foreign key
   - Add `targetReps` to individual `workouts` table (per-workout flexibility)
   - Add `isActive` to `workout_plans` table

3. **Workouts**: Add global workout reference

   - Add `globalWorkoutId` column (references `global_workouts.id`)
   - Rename `name` to `globalWorkoutName` (denormalized from global workout)
   - Store `alternativeWorkouts` as JSON array of globalWorkoutIds

4. **Users**: Embed sync metadata

   - Add `updatedAt` column
   - Add `syncLastTemplateSync` column (replaces separate sync_metadata table)
   - Add `syncLastProgressSync` column

5. **Completed Sets**: Remove redundant userId

   - Remove `userId` column (already in Firestore path, keep in local DB for querying)
   - Keep `workoutName` (stores actual exercise performed)

6. **Sync Service**: Implement batching and cleanup
   - Buffer up to 20 sets before batch write
   - Auto-flush every 60 seconds or on app pause
   - Client-side cleanup of sets older than 2 cycles (plan-dependent: 2 × totalWeeks)

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

| Collection      | Documents per User | Avg Size per Doc | Total Size      |
| --------------- | ------------------ | ---------------- | --------------- |
| global_workouts | 1 (shared)         | 2KB              | 2KB             |
| workout_plans   | 1 (shared)         | 40KB             | 40KB            |
| users           | 1                  | 0.5KB            | 0.5KB           |
| completed_sets  | 768 per cycle      | 0.2KB            | 154KB per cycle |
| sync_metadata   | 1                  | 0.2KB            | 0.2KB           |

**Total for 1 user after 1 cycle (8 weeks)**: ~197KB
**Total after 1 year (6 cycles)**: ~967KB ✅ Under 1MB limit
**Total after 2 years (12 cycles)**: ~1.9MB (exceeds if stored in single doc, but we use subcollections)

**Conclusion**: Separate `completed_sets` documents scale indefinitely without hitting limits.

---

## Cost Estimates (Firestore Pricing)

**Assumptions**:

- 100 active users
- Each user syncs daily
- 1 template download per week (plan + current week only)
- 30 completed sets per day

**Reads** (with optimizations):

- Template sync: 100 users × 5 reads/week × 4 weeks = 2,000 reads/month
  - (1 plan doc + 1 week doc + 1 day doc + 2 workout docs)
- Progress download: 100 users × 1 read/day × 30 days = 3,000 reads/month
- **Total reads**: ~5,000/month

**Writes** (with batch optimization):

- Progress upload: 90,000 sets ÷ 20 (batching) = 4,500 writes/month
- **Total writes**: ~4,500/month

**Storage** (with retention policy):

- 100 users × 400KB (capped at 2 cycles) = 40MB
- Global workouts: 200 workouts × 1KB = 200KB
- Workout plans: 10 plans × 100KB = 1MB
- **Total storage**: ~41MB

**Cost** (as of 2025):

- Reads: 5,000 × $0.06/100k = $0.003
- Writes: 4,500 × $0.18/100k = $0.008
- Storage: 41MB × $0.18/GB = $0.007
- **Total**: ~$0.018/month

**Savings from optimizations**:

- Batch writes: ~95% reduction (was $0.162 without batching, now $0.008)
- Data retention: 50% reduction in storage growth
- Lazy-loading weeks: 50% reduction in template sync reads

**Note**: First 50k reads, 20k writes, 1GB storage are free daily. This entire app would run on free tier until ~1000 active users.

---

## References

- [Firestore Data Model Best Practices](https://firebase.google.com/docs/firestore/data-model)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Flutter Firebase Integration](https://firebase.flutter.dev/)
- [Progressive Overload Formula](./CLAUDE.md#data-architecture)
