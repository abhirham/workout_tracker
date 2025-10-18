/**
 * Migration Script: Add globalWorkoutId references to workout documents
 *
 * This script migrates existing workout documents in Firestore from storing
 * redundant workout metadata (name, type, muscleGroups, equipment) to using
 * globalWorkoutId references to the global_workouts collection.
 *
 * Changes made per workout document:
 * - Add: globalWorkoutId field (reference to global_workouts collection)
 * - Remove: name, type, muscleGroups, equipment fields
 * - Keep: order, numSets, targetReps, baseWeight, restTimerSeconds, workoutDurationSeconds, createdAt, updatedAt
 *
 * Usage:
 *   ts-node scripts/migrate-workouts-to-global-refs.ts
 *
 * Prerequisites:
 *   npm install --save-dev ts-node typescript @types/node
 *   Set up Firebase Admin SDK credentials
 */

import admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';

// Initialize Firebase Admin SDK
// NOTE: Update this path to your Firebase service account key
const serviceAccountPath = path.join(__dirname, '../firebase-service-account.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Firebase service account key not found at:', serviceAccountPath);
  console.error('Please download the service account key from Firebase Console and place it in the admin-dashboard directory');
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

interface GlobalWorkout {
  id: string;
  name: string;
  type: string;
  muscleGroups: string[];
  equipment: string[];
}

interface MigrationStats {
  totalPlans: number;
  totalWeeks: number;
  totalDays: number;
  totalWorkouts: number;
  workoutsUpdated: number;
  workoutsSkipped: number;
  errors: string[];
  warnings: string[];
}

/**
 * Fetch all global workouts and create a name-to-ID mapping
 */
async function fetchGlobalWorkouts(): Promise<Map<string, GlobalWorkout>> {
  const globalWorkouts = new Map<string, GlobalWorkout>();

  console.log('📥 Fetching global workouts...');
  const snapshot = await db.collection('global_workouts').get();

  snapshot.forEach(doc => {
    const data = doc.data();
    globalWorkouts.set(data.name.toLowerCase(), {
      id: doc.id,
      name: data.name,
      type: data.type || 'Weight',
      muscleGroups: data.muscleGroups || [],
      equipment: data.equipment || [],
    });
  });

  console.log(`✅ Loaded ${globalWorkouts.size} global workouts`);
  return globalWorkouts;
}

/**
 * Migrate a single workout document
 */
async function migrateWorkout(
  workoutRef: admin.firestore.DocumentReference,
  workoutData: admin.firestore.DocumentData,
  globalWorkouts: Map<string, GlobalWorkout>,
  stats: MigrationStats
): Promise<void> {
  try {
    // Check if already migrated
    if (workoutData.globalWorkoutId) {
      stats.workoutsSkipped++;
      console.log(`  ⏩ Already migrated: ${workoutData.name || workoutRef.id}`);
      return;
    }

    // Find matching global workout by name (case-insensitive)
    const workoutName = workoutData.name?.toLowerCase();
    if (!workoutName) {
      stats.warnings.push(`Workout ${workoutRef.id} has no name field - skipping`);
      stats.workoutsSkipped++;
      return;
    }

    const globalWorkout = globalWorkouts.get(workoutName);
    if (!globalWorkout) {
      stats.warnings.push(`No global workout found for "${workoutData.name}" (ID: ${workoutRef.id})`);
      stats.workoutsSkipped++;
      return;
    }

    // Update the workout document
    await workoutRef.update({
      globalWorkoutId: globalWorkout.id,
      name: admin.firestore.FieldValue.delete(),
      type: admin.firestore.FieldValue.delete(),
      muscleGroups: admin.firestore.FieldValue.delete(),
      equipment: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    stats.workoutsUpdated++;
    console.log(`  ✅ Migrated: ${workoutData.name} → globalWorkoutId: ${globalWorkout.id}`);
  } catch (error) {
    stats.errors.push(`Failed to migrate workout ${workoutRef.id}: ${error}`);
    console.error(`  ❌ Error migrating workout ${workoutRef.id}:`, error);
  }
}

/**
 * Main migration function
 */
async function migrateWorkoutPlans(): Promise<MigrationStats> {
  const stats: MigrationStats = {
    totalPlans: 0,
    totalWeeks: 0,
    totalDays: 0,
    totalWorkouts: 0,
    workoutsUpdated: 0,
    workoutsSkipped: 0,
    errors: [],
    warnings: [],
  };

  try {
    // Fetch global workouts
    const globalWorkouts = await fetchGlobalWorkouts();

    // Fetch all workout plans
    console.log('\n📥 Fetching workout plans...');
    const plansSnapshot = await db.collection('workout_plans').get();
    stats.totalPlans = plansSnapshot.size;
    console.log(`✅ Found ${stats.totalPlans} workout plan(s)\n`);

    // Process each plan
    for (const planDoc of plansSnapshot.docs) {
      console.log(`\n📋 Processing plan: ${planDoc.data().name} (ID: ${planDoc.id})`);

      // Fetch weeks for this plan
      const weeksSnapshot = await db
        .collection('workout_plans')
        .doc(planDoc.id)
        .collection('weeks')
        .get();

      stats.totalWeeks += weeksSnapshot.size;

      for (const weekDoc of weeksSnapshot.docs) {
        const weekData = weekDoc.data();
        console.log(`\n  📅 Week ${weekData.weekNumber}`);

        // Fetch days for this week
        const daysSnapshot = await db
          .collection('workout_plans')
          .doc(planDoc.id)
          .collection('weeks')
          .doc(weekDoc.id)
          .collection('days')
          .get();

        stats.totalDays += daysSnapshot.size;

        for (const dayDoc of daysSnapshot.docs) {
          const dayData = dayDoc.data();
          console.log(`\n    📆 ${dayData.name || dayDoc.id}`);

          // Fetch workouts for this day
          const workoutsSnapshot = await db
            .collection('workout_plans')
            .doc(planDoc.id)
            .collection('weeks')
            .doc(weekDoc.id)
            .collection('days')
            .doc(dayDoc.id)
            .collection('workouts')
            .get();

          stats.totalWorkouts += workoutsSnapshot.size;

          // Migrate each workout
          for (const workoutDoc of workoutsSnapshot.docs) {
            await migrateWorkout(
              workoutDoc.ref,
              workoutDoc.data(),
              globalWorkouts,
              stats
            );
          }
        }
      }
    }
  } catch (error) {
    console.error('❌ Migration failed:', error);
    stats.errors.push(`Migration failed: ${error}`);
  }

  return stats;
}

/**
 * Print migration summary
 */
function printSummary(stats: MigrationStats): void {
  console.log('\n' + '='.repeat(60));
  console.log('MIGRATION SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total Plans:        ${stats.totalPlans}`);
  console.log(`Total Weeks:        ${stats.totalWeeks}`);
  console.log(`Total Days:         ${stats.totalDays}`);
  console.log(`Total Workouts:     ${stats.totalWorkouts}`);
  console.log(`Workouts Updated:   ${stats.workoutsUpdated}`);
  console.log(`Workouts Skipped:   ${stats.workoutsSkipped}`);
  console.log(`Errors:             ${stats.errors.length}`);
  console.log(`Warnings:           ${stats.warnings.length}`);
  console.log('='.repeat(60));

  if (stats.warnings.length > 0) {
    console.log('\n⚠️  WARNINGS:');
    stats.warnings.forEach((warning, idx) => {
      console.log(`  ${idx + 1}. ${warning}`);
    });
  }

  if (stats.errors.length > 0) {
    console.log('\n❌ ERRORS:');
    stats.errors.forEach((error, idx) => {
      console.log(`  ${idx + 1}. ${error}`);
    });
  }

  // Save detailed log to file
  const logPath = path.join(__dirname, '../migration-log.json');
  fs.writeFileSync(logPath, JSON.stringify(stats, null, 2));
  console.log(`\n📄 Detailed migration log saved to: ${logPath}`);
}

/**
 * Entry point
 */
async function main() {
  console.log('🚀 Starting workout migration to globalWorkoutId references...\n');

  const stats = await migrateWorkoutPlans();
  printSummary(stats);

  if (stats.errors.length === 0) {
    console.log('\n✅ Migration completed successfully!');
  } else {
    console.log('\n⚠️  Migration completed with errors. Please review the log above.');
  }

  process.exit(stats.errors.length === 0 ? 0 : 1);
}

// Run migration
main();
