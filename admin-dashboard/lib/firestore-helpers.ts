import { db } from './firebase';
import {
  collection,
  getDocs,
  deleteDoc,
  doc,
  writeBatch,
  query,
  where,
} from 'firebase/firestore';

/**
 * Recursively deletes a workout plan and all its subcollections (weeks, days, workouts)
 * Uses batched writes for efficiency (max 500 operations per batch)
 */
export async function deleteWorkoutPlanWithSubcollections(planId: string): Promise<void> {
  try {
    console.log(`Starting cascade deletion for plan: ${planId}`);

    // Fetch all weeks for this plan
    const weeksSnapshot = await getDocs(collection(db, 'workout_plans', planId, 'weeks'));
    console.log(`Found ${weeksSnapshot.size} weeks to delete`);

    // For each week, delete all days and workouts
    for (const weekDoc of weeksSnapshot.docs) {
      const weekId = weekDoc.id;
      console.log(`Processing week: ${weekId}`);

      // Fetch all days for this week
      const daysSnapshot = await getDocs(
        collection(db, 'workout_plans', planId, 'weeks', weekId, 'days')
      );
      console.log(`Found ${daysSnapshot.size} days in week ${weekId}`);

      // For each day, delete all workouts
      for (const dayDoc of daysSnapshot.docs) {
        const dayId = dayDoc.id;
        console.log(`Processing day: ${dayId}`);

        // Fetch all workouts for this day
        const workoutsSnapshot = await getDocs(
          collection(db, 'workout_plans', planId, 'weeks', weekId, 'days', dayId, 'workouts')
        );
        console.log(`Found ${workoutsSnapshot.size} workouts in day ${dayId}`);

        // Delete workouts in batches
        await deleteBatch(workoutsSnapshot.docs.map(d => d.ref));
      }

      // Delete days in batches
      await deleteBatch(daysSnapshot.docs.map(d => d.ref));
    }

    // Delete weeks in batches
    await deleteBatch(weeksSnapshot.docs.map(d => d.ref));

    // Finally, delete the plan document itself
    await deleteDoc(doc(db, 'workout_plans', planId));
    console.log(`Successfully deleted plan: ${planId}`);
  } catch (error) {
    console.error('Error in cascade deletion:', error);
    throw error;
  }
}

/**
 * Deletes documents in batches of 500 (Firestore limit)
 */
async function deleteBatch(docRefs: any[]): Promise<void> {
  const batchSize = 500;

  for (let i = 0; i < docRefs.length; i += batchSize) {
    const batch = writeBatch(db);
    const batchRefs = docRefs.slice(i, i + batchSize);

    batchRefs.forEach(ref => {
      batch.delete(ref);
    });

    await batch.commit();
    console.log(`Deleted batch of ${batchRefs.length} documents`);
  }
}

/**
 * Checks if a global workout is referenced in any workout plan
 * Returns the count of plans using this workout
 */
export async function checkGlobalWorkoutReferences(globalWorkoutId: string): Promise<{
  isReferenced: boolean;
  planCount: number;
  planNames: string[];
}> {
  try {
    console.log(`Checking references for global workout: ${globalWorkoutId}`);

    // Fetch all workout plans
    const plansSnapshot = await getDocs(collection(db, 'workout_plans'));
    const referencedPlans: { id: string; name: string }[] = [];

    // For each plan, check if the workout is used in any subcollection
    for (const planDoc of plansSnapshot.docs) {
      const planId = planDoc.id;
      const planName = planDoc.data().name || 'Unnamed Plan';

      // Fetch all weeks for this plan
      const weeksSnapshot = await getDocs(collection(db, 'workout_plans', planId, 'weeks'));

      // Check each week's days for the workout
      for (const weekDoc of weeksSnapshot.docs) {
        const weekId = weekDoc.id;
        const daysSnapshot = await getDocs(
          collection(db, 'workout_plans', planId, 'weeks', weekId, 'days')
        );

        // Check each day's workouts
        for (const dayDoc of daysSnapshot.docs) {
          const dayId = dayDoc.id;

          // Note: We can't query subcollections directly for globalWorkoutId
          // So we need to fetch all workouts and check manually
          const workoutsSnapshot = await getDocs(
            collection(db, 'workout_plans', planId, 'weeks', weekId, 'days', dayId, 'workouts')
          );

          const hasWorkout = workoutsSnapshot.docs.some(workoutDoc => {
            // Check if this workout references the global workout by globalWorkoutId
            return workoutDoc.data().globalWorkoutId === globalWorkoutId;
          });

          if (hasWorkout) {
            referencedPlans.push({ id: planId, name: planName });
            // Break out of the loops for this plan since we found a reference
            break;
          }
        }

        // Break if already found in this plan
        if (referencedPlans.some(p => p.id === planId)) break;
      }

      // Break if already found in this plan
      if (referencedPlans.some(p => p.id === planId)) continue;
    }

    const uniquePlans = Array.from(new Set(referencedPlans.map(p => p.id))).map(id =>
      referencedPlans.find(p => p.id === id)!
    );

    console.log(`Found ${uniquePlans.length} plans referencing this workout`);

    return {
      isReferenced: uniquePlans.length > 0,
      planCount: uniquePlans.length,
      planNames: uniquePlans.map(p => p.name),
    };
  } catch (error) {
    console.error('Error checking workout references:', error);
    throw error;
  }
}
