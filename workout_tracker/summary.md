# Workout Alternatives Feature - Implementation Summary

## Overview

Implemented a workout alternatives feature that allows users to create and switch between alternative exercises (e.g., switching from Bench Press to Dumbbell Press) with independent progress tracking.

## Key Requirements

### User Flow
1. User is on a workout screen (e.g., Bench Press)
2. Click "Alternatives" button at top of screen
3. Modal opens showing:
   - Original workout option
   - List of existing alternatives
   - "Create New Alternative" button
4. User can select an alternative or create a new one
5. When alternative is selected, all progress is tracked under that alternative name
6. **Critical**: If user completes "Dumbbell Press" instead of "Bench Press", history shows "Dumbbell Press" - NO record of "Bench Press" for that day

### Business Rules
- **User-Specific**: Alternatives are per-user, not global
- **Exercise-Tied**: Alternatives are tied to workout exercise type (not specific day/week)
- **Inheritance**: Alternatives inherit set/rep scheme and timer config from original workout
- **Fresh Progress**: Each alternative starts with fresh progress tracking
- **Template Updates**: If template's set/rep scheme changes, all alternatives update automatically
- **Independent History**: Alternatives appear as separate entries in history
- **Sync**: Must sync to both Firestore and local database

## Implementation Details

### 1. Data Model - WorkoutAlternative

**File**: `lib/shared/models/workout_alternative.dart`

```dart
@freezed
class WorkoutAlternative with _$WorkoutAlternative {
  const factory WorkoutAlternative({
    required String id,
    required String userId,
    required String originalWorkoutId,
    required String name,
    required DateTime createdAt,
  }) = _WorkoutAlternative;

  factory WorkoutAlternative.fromJson(Map<String, dynamic> json) =>
      _$WorkoutAlternativeFromJson(json);
}
```

**Fields**:
- `id`: Unique identifier for the alternative
- `userId`: Owner of the alternative (user-specific)
- `originalWorkoutId`: Links to the original workout template
- `name`: Display name (e.g., "Dumbbell Press")
- `createdAt`: Timestamp for ordering

### 2. Updated CompletedSet Model

**File**: `lib/shared/models/completed_set.dart`

**Added Field**:
```dart
String? workoutAlternativeId, // null = original workout, non-null = alternative
```

**Purpose**: Links completed sets to specific alternatives. When NULL, set belongs to original workout. When populated, set belongs to the alternative.

### 3. Database Schema Updates

**File**: `lib/core/database/app_database.dart`

#### New Table: WorkoutAlternatives
```dart
class WorkoutAlternatives extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get originalWorkoutId => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

#### Updated Table: CompletedSets
Added column:
```dart
TextColumn get workoutAlternativeId => text().nullable()();
```

#### Schema Migration (v1 → v2)
```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(completedSets, completedSets.workoutAlternativeId);
        await m.createTable(workoutAlternatives);
      }
    },
  );
}
```

### 4. Repository Layer

**File**: `lib/features/workouts/data/workout_alternative_repository.dart`

**Key Methods**:

```dart
// Create a new alternative
Future<void> createAlternative(model.WorkoutAlternative alternative)

// Get all alternatives for a workout
Future<List<model.WorkoutAlternative>> getAlternativesForWorkout(
  String userId,
  String originalWorkoutId,
)

// Get specific alternative by ID
Future<model.WorkoutAlternative?> getAlternativeById(String id)

// Delete an alternative
Future<void> deleteAlternative(String id)

// Update alternative name
Future<void> updateAlternativeName(String id, String newName)
```

**Important Note**: Uses import alias to avoid naming conflict with Drift-generated code:
```dart
import '../../../shared/models/workout_alternative.dart' as model;
```

### 5. UI Implementation

**File**: `lib/features/workouts/presentation/workout_list_screen.dart`

#### State Variables Added:
```dart
String? selectedAlternativeId;   // null = original workout
String? selectedAlternativeName; // Name to display
```

#### Alternatives Button:
```dart
OutlinedButton.icon(
  onPressed: _showAlternativesModal,
  icon: const Icon(Icons.swap_horiz, size: 18),
  label: const Text('Alternatives'),
  // ...
)
```

#### Display Logic:
```dart
final displayName = selectedAlternativeName ?? (workout['name'] as String);
```

#### Bottom Sheet Modal:
- Shows original workout with radio button
- Lists all alternatives with radio buttons
- "Create New Alternative" button at bottom
- Opens dialog for entering alternative name
- Callbacks for selection and creation

## Current Status

### ✅ Completed
- [x] Data model created with Freezed
- [x] Database schema updated (v1 → v2 migration)
- [x] Repository layer implemented with CRUD operations
- [x] UI components added (button, modal, dialog)
- [x] Code generation completed successfully
- [x] Build verified with no critical errors

### 🔄 Pending (TODO Comments in Code)

#### 1. Wire Repository to UI
**Location**: `workout_list_screen.dart:203`
```dart
void _showAlternativesModal() {
  // TODO: Load alternatives from repository
  // TODO: Reload progress for selected alternative
}
```

**What's needed**:
- Create Riverpod provider for `WorkoutAlternativeRepository`
- Replace mock data with actual repository calls
- Load alternatives using `getAlternativesForWorkout(userId, workoutId)`

#### 2. Implement Create Alternative
**Location**: `workout_list_screen.dart:216`
```dart
onCreateAlternative: (String name) {
  // TODO: Create alternative in repository
}
```

**What's needed**:
- Generate UUID for new alternative
- Call `repository.createAlternative()` with user ID and workout ID
- Refresh alternatives list
- Auto-select newly created alternative

#### 3. Update Progress Tracking
**Location**: `workout_list_screen.dart` (in `_saveSet` method)

**What's needed**:
- When saving completed set, include `workoutAlternativeId`
- Reload progress when alternative is selected
- Filter progress queries by both `workoutId` AND `workoutAlternativeId`
- Show fresh progress for new alternatives

#### 4. Firestore Sync
**Not yet started**

**What's needed**:
- Create Firestore collection: `/user_progress/{userId}/workout_alternatives/{altId}`
- Implement bidirectional sync
- Update sync service to handle alternatives
- Handle conflict resolution (last-write-wins)

#### 5. Update History/Analytics
**Not yet started**

**What's needed**:
- Update history queries to show alternative name (not original workout)
- Ensure separate entries for each alternative
- Update analytics to track alternative usage

## Technical Notes

### Naming Conflict Resolution
- **Issue**: Drift generates `WorkoutAlternative` class that conflicts with Freezed model
- **Solution**: Import alias `as model` in repository
- **Pattern**: `model.WorkoutAlternative` for Freezed model, generated class used internally

### Migration Strategy
- Schema version bumped from 1 to 2
- Migration adds column and table without data loss
- Existing users will auto-migrate on app update

### Progress Tracking Logic
```
If workoutAlternativeId == NULL:
  → Progress belongs to original workout

If workoutAlternativeId == "alt-123":
  → Progress belongs to alternative "alt-123"
  → Query: WHERE workoutId = X AND workoutAlternativeId = "alt-123"
```

## Next Steps (Priority Order)

1. **Create Riverpod Provider**
   ```dart
   final workoutAlternativeRepositoryProvider = Provider<WorkoutAlternativeRepository>((ref) {
     final database = ref.watch(databaseProvider);
     return WorkoutAlternativeRepository(database);
   });
   ```

2. **Wire Modal to Repository**
   - Load alternatives on modal open
   - Implement create alternative callback
   - Handle selection logic

3. **Update Progress Tracking**
   - Save `workoutAlternativeId` in `CompletedSet`
   - Load progress filtered by alternative
   - Reset UI state when switching alternatives

4. **Implement Firestore Sync**
   - Create Firestore collections
   - Add sync logic for alternatives
   - Test offline/online transitions

5. **Update History**
   - Show alternative names in history
   - Separate entries per alternative

## File Reference

### Created Files
- `lib/shared/models/workout_alternative.dart` - Freezed model
- `lib/features/workouts/data/workout_alternative_repository.dart` - Data access layer

### Modified Files
- `lib/shared/models/completed_set.dart` - Added `workoutAlternativeId` field
- `lib/core/database/app_database.dart` - Added table, migration, schema v2
- `lib/features/workouts/presentation/workout_list_screen.dart` - Added UI components

### Generated Files (by build_runner)
- `*.freezed.dart` - Freezed code generation
- `*.g.dart` - JSON serialization and Drift code generation
- `app_database.g.dart` - Drift database implementation

## Testing Considerations

### Manual Testing Scenarios
1. Create alternative → verify saved to database
2. Switch to alternative → verify progress resets
3. Complete set on alternative → verify saved with alternativeId
4. Switch back to original → verify separate progress
5. View history → verify shows alternative name, not original
6. Delete alternative → verify removed from database
7. Update template → verify alternatives inherit changes

### Database Migration Testing
1. Install app with schema v1
2. Add some workout progress
3. Update app to schema v2
4. Verify data intact and new column/table exists

## Architecture Alignment

This implementation follows the project's architecture:

- ✅ **Offline-First**: All operations write to local DB first
- ✅ **User-Specific Data**: Alternatives stored per userId
- ✅ **Template Inheritance**: Alternatives reference original workout
- ✅ **Freezed Models**: Immutable data classes
- ✅ **Drift Repository Pattern**: Type-safe database queries
- ✅ **Riverpod State Management**: (pending provider setup)
- ✅ **Firebase Sync**: (structure ready, implementation pending)

## Questions & Decisions Made

**Q**: Should alternatives be global or user-specific?
**A**: User-specific (each user creates their own)

**Q**: How are alternatives tied to workouts?
**A**: By exercise type (originalWorkoutId), not by specific day/week

**Q**: How is progress tracked?
**A**: Completely separate - alternatives are true replacements, not variations

**Q**: What happens to history?
**A**: Shows actual alternative name used (e.g., "Dumbbell Press"), no record of original if not performed

**Q**: What's inherited?
**A**: Set/rep scheme and timer config from original workout

**Q**: What about template updates?
**A**: Alternatives automatically reflect template changes (sets, reps, timer)

---

**Last Updated**: 2025-10-08
**Implementation Status**: Foundation Complete, Wiring Pending
**Next Action**: Create Riverpod provider and wire repository to UI
