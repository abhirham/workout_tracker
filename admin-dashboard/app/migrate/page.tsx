'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { db } from '@/lib/firebase';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  updateDoc,
  deleteField,
  Timestamp,
} from 'firebase/firestore';
import { useToast } from '@/app/context/ToastContext';

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

interface GlobalWorkout {
  id: string;
  name: string;
  type: string;
  muscleGroups: string[];
  equipment: string[];
}

export default function MigratePage() {
  const router = useRouter();
  const toast = useToast();
  const [isRunning, setIsRunning] = useState(false);
  const [stats, setStats] = useState<MigrationStats>({
    totalPlans: 0,
    totalWeeks: 0,
    totalDays: 0,
    totalWorkouts: 0,
    workoutsUpdated: 0,
    workoutsSkipped: 0,
    errors: [],
    warnings: [],
  });
  const [logs, setLogs] = useState<string[]>([]);
  const [isComplete, setIsComplete] = useState(false);

  const addLog = (message: string) => {
    setLogs((prev) => [...prev, `[${new Date().toLocaleTimeString()}] ${message}`]);
  };

  const runMigration = async () => {
    if (isRunning) return;

    const confirmed = confirm(
      'This will migrate all workout documents in Firestore to use globalWorkoutId references.\n\n' +
      'The migration will:\n' +
      '1. Add globalWorkoutId field to all workouts\n' +
      '2. Remove redundant fields (name, type, muscleGroups, equipment)\n\n' +
      'This operation is IRREVERSIBLE. Make sure you have a backup!\n\n' +
      'Continue?'
    );

    if (!confirmed) return;

    setIsRunning(true);
    setIsComplete(false);
    setLogs([]);
    const newStats: MigrationStats = {
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
      addLog('🚀 Starting migration...');

      // Fetch all global workouts
      addLog('📥 Fetching global workouts...');
      const globalWorkoutsMap = new Map<string, GlobalWorkout>();
      const globalWorkoutsSnapshot = await getDocs(collection(db, 'global_workouts'));

      globalWorkoutsSnapshot.forEach((doc) => {
        const data = doc.data();
        globalWorkoutsMap.set(data.name.toLowerCase(), {
          id: doc.id,
          name: data.name,
          type: data.type || 'Weight',
          muscleGroups: data.muscleGroups || [],
          equipment: data.equipment || [],
        });
      });

      addLog(`✅ Loaded ${globalWorkoutsMap.size} global workouts`);

      // Fetch all workout plans
      addLog('📥 Fetching workout plans...');
      const plansSnapshot = await getDocs(collection(db, 'workout_plans'));
      newStats.totalPlans = plansSnapshot.size;
      addLog(`✅ Found ${newStats.totalPlans} workout plan(s)`);

      // Process each plan
      for (const planDoc of plansSnapshot.docs) {
        const planData = planDoc.data();
        addLog(`\n📋 Processing plan: ${planData.name} (ID: ${planDoc.id})`);

        // Fetch weeks for this plan
        const weeksSnapshot = await getDocs(
          collection(db, 'workout_plans', planDoc.id, 'weeks')
        );
        newStats.totalWeeks += weeksSnapshot.size;

        for (const weekDoc of weeksSnapshot.docs) {
          const weekData = weekDoc.data();
          addLog(`  📅 Week ${weekData.weekNumber}`);

          // Fetch days for this week
          const daysSnapshot = await getDocs(
            collection(db, 'workout_plans', planDoc.id, 'weeks', weekDoc.id, 'days')
          );
          newStats.totalDays += daysSnapshot.size;

          for (const dayDoc of daysSnapshot.docs) {
            const dayData = dayDoc.data();
            addLog(`    📆 ${dayData.name || dayDoc.id}`);

            // Fetch workouts for this day
            const workoutsSnapshot = await getDocs(
              collection(db, 'workout_plans', planDoc.id, 'weeks', weekDoc.id, 'days', dayDoc.id, 'workouts')
            );
            newStats.totalWorkouts += workoutsSnapshot.size;

            // Migrate each workout
            for (const workoutDoc of workoutsSnapshot.docs) {
              const workoutData = workoutDoc.data();

              // Check if already migrated
              if (workoutData.globalWorkoutId) {
                newStats.workoutsSkipped++;
                addLog(`      ⏩ Already migrated: ${workoutData.name || workoutDoc.id}`);
                continue;
              }

              // Find matching global workout by name
              const workoutName = workoutData.name?.toLowerCase();
              if (!workoutName) {
                newStats.warnings.push(`Workout ${workoutDoc.id} has no name field - skipping`);
                newStats.workoutsSkipped++;
                addLog(`      ⚠️  No name field: ${workoutDoc.id}`);
                continue;
              }

              const globalWorkout = globalWorkoutsMap.get(workoutName);
              if (!globalWorkout) {
                newStats.warnings.push(`No global workout found for "${workoutData.name}" (ID: ${workoutDoc.id})`);
                newStats.workoutsSkipped++;
                addLog(`      ⚠️  No match found: ${workoutData.name}`);
                continue;
              }

              // Update the workout document
              try {
                await updateDoc(workoutDoc.ref, {
                  globalWorkoutId: globalWorkout.id,
                  name: deleteField(),
                  type: deleteField(),
                  muscleGroups: deleteField(),
                  equipment: deleteField(),
                  updatedAt: Timestamp.now(),
                });

                newStats.workoutsUpdated++;
                addLog(`      ✅ Migrated: ${workoutData.name} → ${globalWorkout.id}`);
              } catch (error) {
                const errorMsg = `Failed to migrate workout ${workoutDoc.id}: ${error}`;
                newStats.errors.push(errorMsg);
                addLog(`      ❌ Error: ${error}`);
              }
            }
          }
        }
      }

      setStats(newStats);
      setIsComplete(true);
      addLog('\n' + '='.repeat(60));
      addLog('✅ MIGRATION COMPLETED!');
      addLog('='.repeat(60));
      addLog(`Total Plans:        ${newStats.totalPlans}`);
      addLog(`Total Weeks:        ${newStats.totalWeeks}`);
      addLog(`Total Days:         ${newStats.totalDays}`);
      addLog(`Total Workouts:     ${newStats.totalWorkouts}`);
      addLog(`Workouts Updated:   ${newStats.workoutsUpdated}`);
      addLog(`Workouts Skipped:   ${newStats.workoutsSkipped}`);
      addLog(`Errors:             ${newStats.errors.length}`);
      addLog(`Warnings:           ${newStats.warnings.length}`);
      addLog('='.repeat(60));

      if (newStats.errors.length === 0) {
        toast.success('Migration completed successfully!');
      } else {
        toast.warning('Migration completed with errors. Check the logs below.');
      }
    } catch (error) {
      console.error('Migration failed:', error);
      addLog(`\n❌ MIGRATION FAILED: ${error}`);
      toast.error('Migration failed. Check the console for details.');
    } finally {
      setIsRunning(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[32px] font-bold text-[#000000]">Database Migration</h1>
          <p className="text-[14px] text-[#64748B] mt-1">
            Migrate workout documents to use globalWorkoutId references
          </p>
        </div>
        <button
          onClick={() => router.push('/workout-plans')}
          className="px-4 py-2 text-[14px] font-medium text-[#64748B] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors"
        >
          Back to Plans
        </button>
      </div>

      {/* Migration Info */}
      <div className="bg-[#FEF3C7] border border-[#FCD34D] rounded-lg p-6">
        <div className="flex items-start gap-3">
          <svg className="w-6 h-6 text-[#F59E0B] flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <div className="flex-1">
            <h3 className="text-[16px] font-semibold text-[#92400E] mb-2">⚠️ Important: Read Before Running</h3>
            <ul className="text-[14px] text-[#92400E] space-y-1 list-disc list-inside">
              <li>This migration is <strong>IRREVERSIBLE</strong></li>
              <li>All workout documents will be updated to reference global_workouts</li>
              <li>Redundant fields (name, type, muscleGroups, equipment) will be removed</li>
              <li>Make sure you have a Firestore backup before proceeding</li>
              <li>The migration is idempotent (safe to run multiple times)</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Stats Card */}
      {(isRunning || isComplete) && (
        <div className="bg-white border border-[#E2E8F0] rounded-lg p-6">
          <h3 className="text-[18px] font-semibold text-[#000000] mb-4">Migration Statistics</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="bg-[#F8FAFC] rounded-lg p-4">
              <div className="text-[24px] font-bold text-[#000000]">{stats.totalPlans}</div>
              <div className="text-[13px] text-[#64748B]">Total Plans</div>
            </div>
            <div className="bg-[#F8FAFC] rounded-lg p-4">
              <div className="text-[24px] font-bold text-[#000000]">{stats.totalWorkouts}</div>
              <div className="text-[13px] text-[#64748B]">Total Workouts</div>
            </div>
            <div className="bg-[#DCFCE7] rounded-lg p-4">
              <div className="text-[24px] font-bold text-[#16A34A]">{stats.workoutsUpdated}</div>
              <div className="text-[13px] text-[#15803D]">Updated</div>
            </div>
            <div className="bg-[#FEF3C7] rounded-lg p-4">
              <div className="text-[24px] font-bold text-[#F59E0B]">{stats.workoutsSkipped}</div>
              <div className="text-[13px] text-[#D97706]">Skipped</div>
            </div>
          </div>
          {stats.errors.length > 0 && (
            <div className="mt-4 bg-[#FEE2E2] rounded-lg p-4">
              <div className="text-[16px] font-semibold text-[#DC2626] mb-2">
                ❌ {stats.errors.length} Error(s)
              </div>
              <div className="text-[13px] text-[#991B1B] space-y-1">
                {stats.errors.slice(0, 5).map((error, idx) => (
                  <div key={idx}>• {error}</div>
                ))}
                {stats.errors.length > 5 && (
                  <div className="text-[#7F1D1D]">... and {stats.errors.length - 5} more</div>
                )}
              </div>
            </div>
          )}
          {stats.warnings.length > 0 && (
            <div className="mt-4 bg-[#FEF3C7] rounded-lg p-4">
              <div className="text-[16px] font-semibold text-[#D97706] mb-2">
                ⚠️ {stats.warnings.length} Warning(s)
              </div>
              <div className="text-[13px] text-[#92400E] space-y-1">
                {stats.warnings.slice(0, 5).map((warning, idx) => (
                  <div key={idx}>• {warning}</div>
                ))}
                {stats.warnings.length > 5 && (
                  <div className="text-[#78350F]">... and {stats.warnings.length - 5} more</div>
                )}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Run Migration Button */}
      <div className="flex items-center justify-center">
        <button
          onClick={runMigration}
          disabled={isRunning}
          className={`px-8 py-4 text-[16px] font-semibold rounded-lg transition-colors flex items-center gap-3 ${
            isRunning
              ? 'bg-[#94A3B8] text-white cursor-not-allowed'
              : 'bg-[#DC2626] text-white hover:bg-[#B91C1C]'
          }`}
        >
          {isRunning ? (
            <>
              <svg className="w-5 h-5 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Running Migration...
            </>
          ) : (
            <>
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              Run Migration
            </>
          )}
        </button>
      </div>

      {/* Migration Logs */}
      {logs.length > 0 && (
        <div className="bg-[#0F172A] rounded-lg p-6 font-mono text-[13px] overflow-auto max-h-[600px]">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-[16px] font-semibold text-white">Migration Logs</h3>
            <button
              onClick={() => {
                const logsText = logs.join('\n');
                navigator.clipboard.writeText(logsText);
                toast.success('Logs copied to clipboard!');
              }}
              className="px-3 py-1.5 text-[13px] font-medium text-white bg-[#334155] rounded hover:bg-[#475569] transition-colors"
            >
              Copy Logs
            </button>
          </div>
          <div className="space-y-0.5 text-[#E2E8F0]">
            {logs.map((log, idx) => (
              <div key={idx} className="whitespace-pre-wrap break-words">
                {log}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Success Message */}
      {isComplete && stats.errors.length === 0 && (
        <div className="bg-[#DCFCE7] border border-[#86EFAC] rounded-lg p-6 text-center">
          <svg className="w-16 h-16 text-[#16A34A] mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 className="text-[20px] font-bold text-[#16A34A] mb-2">Migration Successful!</h3>
          <p className="text-[14px] text-[#15803D] mb-4">
            All workout documents have been successfully migrated to use globalWorkoutId references.
          </p>
          <button
            onClick={() => router.push('/workout-plans')}
            className="px-6 py-2.5 bg-[#16A34A] text-white text-[14px] font-medium rounded-lg hover:bg-[#15803D] transition-colors"
          >
            Go to Workout Plans
          </button>
        </div>
      )}
    </div>
  );
}
