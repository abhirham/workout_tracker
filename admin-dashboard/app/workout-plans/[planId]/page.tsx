'use client';

import { useState, useEffect } from 'react';
import { db } from '@/lib/firebase';
import {
  collection,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  orderBy,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';

interface Week {
  id: string;
  planId: string;
  weekNumber: number;
  name: string;
}

interface Day {
  id: string;
  weekId: string;
  dayNumber: number;
  name: string;
}

interface Workout {
  id: string;
  planId: string;
  dayId: string;
  globalWorkoutId: string;
  name: string;
  order: number;
  notes?: string;
  baseWeights?: number[];
  targetReps?: number;
  restTimerSeconds?: number;
  workoutDurationSeconds?: number;
  alternativeWorkouts?: string[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

interface GlobalWorkout {
  id: string;
  name: string;
  type: 'weight' | 'timer';
}

export default function PlanDetailPage() {
  const params = useParams();
  const router = useRouter();
  const planId = params.planId as string;

  const [planName, setPlanName] = useState('');
  const [weeks, setWeeks] = useState<Week[]>([]);
  const [selectedWeek, setSelectedWeek] = useState<Week | null>(null);
  const [days, setDays] = useState<Day[]>([]);
  const [selectedDay, setSelectedDay] = useState<Day | null>(null);
  const [workouts, setWorkouts] = useState<Workout[]>([]);
  const [globalWorkouts, setGlobalWorkouts] = useState<GlobalWorkout[]>([]);
  const [loading, setLoading] = useState(true);

  // Modals
  const [showWeekModal, setShowWeekModal] = useState(false);
  const [showDayModal, setShowDayModal] = useState(false);
  const [showWorkoutModal, setShowWorkoutModal] = useState(false);

  // Form states
  const [weekForm, setWeekForm] = useState({ weekNumber: 1, name: '' });
  const [dayForm, setDayForm] = useState({ dayNumber: 1, name: '' });
  const [workoutForm, setWorkoutForm] = useState({
    globalWorkoutId: '',
    name: '',
    order: 1,
    notes: '',
    baseWeights: '',
    targetReps: '',
    restTimerSeconds: '45',
    workoutDurationSeconds: '',
    alternativeWorkouts: '',
  });

  useEffect(() => {
    loadPlanData();
    loadGlobalWorkouts();
  }, [planId]);

  useEffect(() => {
    if (selectedWeek) {
      loadDays(selectedWeek.id);
    }
  }, [selectedWeek]);

  useEffect(() => {
    if (selectedDay) {
      loadWorkouts(selectedDay.id);
    }
  }, [selectedDay]);

  const loadPlanData = async () => {
    try {
      const planDoc = await getDoc(doc(db, 'workout_plans', planId));
      if (planDoc.exists()) {
        setPlanName(planDoc.data().name);
      }
      await loadWeeks();
    } catch (error) {
      console.error('Error loading plan:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadWeeks = async () => {
    try {
      const weeksRef = collection(db, 'workout_plans', planId, 'weeks');
      const q = query(weeksRef, orderBy('weekNumber'));
      const snapshot = await getDocs(q);
      const weeksData = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Week[];
      setWeeks(weeksData);

      if (weeksData.length > 0 && !selectedWeek) {
        setSelectedWeek(weeksData[0]);
      }
    } catch (error) {
      console.error('Error loading weeks:', error);
    }
  };

  const loadDays = async (weekId: string) => {
    try {
      const daysRef = collection(db, 'workout_plans', planId, 'weeks', weekId, 'days');
      const q = query(daysRef, orderBy('dayNumber'));
      const snapshot = await getDocs(q);
      const daysData = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Day[];
      setDays(daysData);

      if (daysData.length > 0) {
        setSelectedDay(daysData[0]);
      } else {
        setSelectedDay(null);
        setWorkouts([]);
      }
    } catch (error) {
      console.error('Error loading days:', error);
    }
  };

  const loadWorkouts = async (dayId: string) => {
    try {
      const workoutsRef = collection(db, 'workout_plans', planId, 'weeks', selectedWeek!.id, 'days', dayId, 'workouts');
      const q = query(workoutsRef, orderBy('order'));
      const snapshot = await getDocs(q);
      const workoutsData = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Workout[];
      setWorkouts(workoutsData);
    } catch (error) {
      console.error('Error loading workouts:', error);
    }
  };

  const loadGlobalWorkouts = async () => {
    try {
      const snapshot = await getDocs(collection(db, 'global_workouts'));
      const workoutsData = snapshot.docs.map(doc => ({
        id: doc.id,
        name: doc.data().name,
        type: doc.data().type,
      })) as GlobalWorkout[];
      setGlobalWorkouts(workoutsData.sort((a, b) => a.name.localeCompare(b.name)));
    } catch (error) {
      console.error('Error loading global workouts:', error);
    }
  };

  const handleCreateWeek = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const weeksRef = collection(db, 'workout_plans', planId, 'weeks');
      await addDoc(weeksRef, {
        planId,
        weekNumber: weekForm.weekNumber,
        name: weekForm.name.trim(),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      alert('Week created successfully!');
      setShowWeekModal(false);
      setWeekForm({ weekNumber: weeks.length + 1, name: '' });
      loadWeeks();
    } catch (error) {
      console.error('Error creating week:', error);
      alert('Failed to create week');
    }
  };

  const handleCreateDay = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedWeek) return;

    try {
      const daysRef = collection(db, 'workout_plans', planId, 'weeks', selectedWeek.id, 'days');
      await addDoc(daysRef, {
        weekId: selectedWeek.id,
        dayNumber: dayForm.dayNumber,
        name: dayForm.name.trim(),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      alert('Day created successfully!');
      setShowDayModal(false);
      setDayForm({ dayNumber: days.length + 1, name: '' });
      loadDays(selectedWeek.id);
    } catch (error) {
      console.error('Error creating day:', error);
      alert('Failed to create day');
    }
  };

  const handleCreateWorkout = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedWeek || !selectedDay) return;

    const selectedGlobalWorkout = globalWorkouts.find(w => w.id === workoutForm.globalWorkoutId);
    if (!selectedGlobalWorkout) {
      alert('Please select a global workout');
      return;
    }

    try {
      const workoutsRef = collection(db, 'workout_plans', planId, 'weeks', selectedWeek.id, 'days', selectedDay.id, 'workouts');

      const baseWeights = workoutForm.baseWeights
        ? workoutForm.baseWeights.split(',').map(w => parseFloat(w.trim())).filter(w => !isNaN(w))
        : null;

      const alternativeWorkouts = workoutForm.alternativeWorkouts
        ? workoutForm.alternativeWorkouts.split(',').map(w => w.trim()).filter(Boolean)
        : null;

      await addDoc(workoutsRef, {
        planId,
        dayId: selectedDay.id,
        globalWorkoutId: workoutForm.globalWorkoutId,
        name: workoutForm.name.trim() || selectedGlobalWorkout.name,
        order: workoutForm.order,
        notes: workoutForm.notes.trim() || null,
        baseWeights,
        targetReps: workoutForm.targetReps ? parseInt(workoutForm.targetReps) : null,
        restTimerSeconds: workoutForm.restTimerSeconds ? parseInt(workoutForm.restTimerSeconds) : null,
        workoutDurationSeconds: workoutForm.workoutDurationSeconds ? parseInt(workoutForm.workoutDurationSeconds) : null,
        alternativeWorkouts,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      alert('Workout added successfully!');
      setShowWorkoutModal(false);
      resetWorkoutForm();
      loadWorkouts(selectedDay.id);
    } catch (error) {
      console.error('Error creating workout:', error);
      alert('Failed to add workout');
    }
  };

  const resetWorkoutForm = () => {
    setWorkoutForm({
      globalWorkoutId: '',
      name: '',
      order: workouts.length + 1,
      notes: '',
      baseWeights: '',
      targetReps: '',
      restTimerSeconds: '45',
      workoutDurationSeconds: '',
      alternativeWorkouts: '',
    });
  };

  const handleDeleteWeek = async (weekId: string) => {
    if (!confirm('Delete this week? This will also delete all days and workouts in this week.')) return;

    try {
      await deleteDoc(doc(db, 'workout_plans', planId, 'weeks', weekId));
      alert('Week deleted successfully!');
      setSelectedWeek(null);
      setSelectedDay(null);
      setDays([]);
      setWorkouts([]);
      loadWeeks();
    } catch (error) {
      console.error('Error deleting week:', error);
      alert('Failed to delete week');
    }
  };

  const handleDeleteDay = async (weekId: string, dayId: string) => {
    if (!confirm('Delete this day? This will also delete all workouts in this day.')) return;

    try {
      await deleteDoc(doc(db, 'workout_plans', planId, 'weeks', weekId, 'days', dayId));
      alert('Day deleted successfully!');
      setSelectedDay(null);
      setWorkouts([]);
      if (selectedWeek) loadDays(selectedWeek.id);
    } catch (error) {
      console.error('Error deleting day:', error);
      alert('Failed to delete day');
    }
  };

  const handleDeleteWorkout = async (workoutId: string) => {
    if (!confirm('Delete this workout?')) return;
    if (!selectedWeek || !selectedDay) return;

    try {
      await deleteDoc(doc(db, 'workout_plans', planId, 'weeks', selectedWeek.id, 'days', selectedDay.id, 'workouts', workoutId));
      alert('Workout deleted successfully!');
      loadWorkouts(selectedDay.id);
    } catch (error) {
      console.error('Error deleting workout:', error);
      alert('Failed to delete workout');
    }
  };

  if (loading) {
    return <div className="flex justify-center items-center h-64"><div className="text-xl text-gray-600">Loading...</div></div>;
  }

  return (
    <div className="px-4 py-6">
      {/* Header */}
      <div className="mb-6">
        <Link href="/workout-plans" className="text-primary-600 hover:text-primary-900 text-sm mb-2 inline-block">
          ← Back to Plans
        </Link>
        <h1 className="text-3xl font-bold text-gray-900">{planName}</h1>
        <p className="text-gray-600 mt-1">Manage weeks, days, and workouts</p>
      </div>

      {/* Three-column layout */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Weeks Column */}
        <div className="bg-white shadow rounded-lg p-4">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Weeks ({weeks.length})</h2>
            <button
              onClick={() => {
                setWeekForm({ weekNumber: weeks.length + 1, name: `Week ${weeks.length + 1}` });
                setShowWeekModal(true);
              }}
              className="text-primary-600 hover:text-primary-900 text-sm font-medium"
            >
              + Add Week
            </button>
          </div>
          <div className="space-y-2">
            {weeks.map(week => (
              <div
                key={week.id}
                className={`p-3 rounded border cursor-pointer ${
                  selectedWeek?.id === week.id ? 'border-primary-500 bg-primary-50' : 'border-gray-200 hover:border-gray-300'
                }`}
                onClick={() => setSelectedWeek(week)}
              >
                <div className="flex justify-between items-start">
                  <div>
                    <div className="font-medium text-gray-900">{week.name}</div>
                    <div className="text-xs text-gray-500">Week {week.weekNumber}</div>
                  </div>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDeleteWeek(week.id);
                    }}
                    className="text-red-600 hover:text-red-900 text-xs"
                  >
                    Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Days Column */}
        <div className="bg-white shadow rounded-lg p-4">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Days ({days.length})</h2>
            {selectedWeek && (
              <button
                onClick={() => {
                  setDayForm({ dayNumber: days.length + 1, name: `Day ${days.length + 1}` });
                  setShowDayModal(true);
                }}
                className="text-primary-600 hover:text-primary-900 text-sm font-medium"
              >
                + Add Day
              </button>
            )}
          </div>
          {!selectedWeek ? (
            <p className="text-gray-500 text-sm">Select a week to view days</p>
          ) : (
            <div className="space-y-2">
              {days.map(day => (
                <div
                  key={day.id}
                  className={`p-3 rounded border cursor-pointer ${
                    selectedDay?.id === day.id ? 'border-primary-500 bg-primary-50' : 'border-gray-200 hover:border-gray-300'
                  }`}
                  onClick={() => setSelectedDay(day)}
                >
                  <div className="flex justify-between items-start">
                    <div>
                      <div className="font-medium text-gray-900">{day.name}</div>
                      <div className="text-xs text-gray-500">Day {day.dayNumber}</div>
                    </div>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDeleteDay(selectedWeek!.id, day.id);
                      }}
                      className="text-red-600 hover:text-red-900 text-xs"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Workouts Column */}
        <div className="bg-white shadow rounded-lg p-4">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-semibold text-gray-900">Workouts ({workouts.length})</h2>
            {selectedDay && (
              <button
                onClick={() => {
                  resetWorkoutForm();
                  setShowWorkoutModal(true);
                }}
                className="text-primary-600 hover:text-primary-900 text-sm font-medium"
              >
                + Add Workout
              </button>
            )}
          </div>
          {!selectedDay ? (
            <p className="text-gray-500 text-sm">Select a day to view workouts</p>
          ) : (
            <div className="space-y-2">
              {workouts.map(workout => (
                <div key={workout.id} className="p-3 rounded border border-gray-200">
                  <div className="flex justify-between items-start mb-2">
                    <div className="font-medium text-gray-900">{workout.name}</div>
                    <button
                      onClick={() => handleDeleteWorkout(workout.id)}
                      className="text-red-600 hover:text-red-900 text-xs"
                    >
                      Delete
                    </button>
                  </div>
                  {workout.targetReps && (
                    <div className="text-xs text-gray-600">Target: {workout.targetReps} reps</div>
                  )}
                  {workout.baseWeights && (
                    <div className="text-xs text-gray-600">Base weights: {workout.baseWeights.join(', ')} lbs</div>
                  )}
                  {workout.notes && (
                    <div className="text-xs text-gray-500 mt-1">{workout.notes}</div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Week Modal */}
      {showWeekModal && (
        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h3 className="text-lg font-medium mb-4">Create New Week</h3>
            <form onSubmit={handleCreateWeek} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Week Number</label>
                <input
                  type="number"
                  required
                  min="1"
                  value={weekForm.weekNumber}
                  onChange={(e) => setWeekForm({ ...weekForm, weekNumber: parseInt(e.target.value) })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Week Name</label>
                <input
                  type="text"
                  required
                  value={weekForm.name}
                  onChange={(e) => setWeekForm({ ...weekForm, name: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                />
              </div>
              <div className="flex justify-end space-x-3">
                <button type="button" onClick={() => setShowWeekModal(false)} className="px-4 py-2 border border-gray-300 rounded-md">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-primary-600 text-white rounded-md hover:bg-primary-700">Create</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Day Modal */}
      {showDayModal && (
        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h3 className="text-lg font-medium mb-4">Create New Day</h3>
            <form onSubmit={handleCreateDay} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Day Number</label>
                <input
                  type="number"
                  required
                  min="1"
                  value={dayForm.dayNumber}
                  onChange={(e) => setDayForm({ ...dayForm, dayNumber: parseInt(e.target.value) })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700">Day Name</label>
                <input
                  type="text"
                  required
                  value={dayForm.name}
                  onChange={(e) => setDayForm({ ...dayForm, name: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                />
              </div>
              <div className="flex justify-end space-x-3">
                <button type="button" onClick={() => setShowDayModal(false)} className="px-4 py-2 border border-gray-300 rounded-md">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-primary-600 text-white rounded-md hover:bg-primary-700">Create</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Workout Modal */}
      {showWorkoutModal && (
        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6">
            <h3 className="text-lg font-medium mb-4">Add Workout</h3>
            <form onSubmit={handleCreateWorkout} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Global Workout</label>
                <select
                  required
                  value={workoutForm.globalWorkoutId}
                  onChange={(e) => {
                    const selected = globalWorkouts.find(w => w.id === e.target.value);
                    setWorkoutForm({
                      ...workoutForm,
                      globalWorkoutId: e.target.value,
                      name: selected?.name || '',
                    });
                  }}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                >
                  <option value="">Select a workout</option>
                  {globalWorkouts.map(workout => (
                    <option key={workout.id} value={workout.id}>
                      {workout.name} ({workout.type})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Order</label>
                <input
                  type="number"
                  required
                  min="1"
                  value={workoutForm.order}
                  onChange={(e) => setWorkoutForm({ ...workoutForm, order: parseInt(e.target.value) })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Base Weights (comma-separated, lbs)</label>
                <input
                  type="text"
                  value={workoutForm.baseWeights}
                  onChange={(e) => setWorkoutForm({ ...workoutForm, baseWeights: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                  placeholder="e.g., 45, 95, 135, 185"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Target Reps</label>
                <input
                  type="number"
                  value={workoutForm.targetReps}
                  onChange={(e) => setWorkoutForm({ ...workoutForm, targetReps: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Rest Timer (seconds)</label>
                <input
                  type="number"
                  value={workoutForm.restTimerSeconds}
                  onChange={(e) => setWorkoutForm({ ...workoutForm, restTimerSeconds: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Notes</label>
                <textarea
                  value={workoutForm.notes}
                  onChange={(e) => setWorkoutForm({ ...workoutForm, notes: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3"
                  rows={2}
                />
              </div>

              <div className="flex justify-end space-x-3 pt-4 border-t">
                <button type="button" onClick={() => setShowWorkoutModal(false)} className="px-4 py-2 border border-gray-300 rounded-md">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-primary-600 text-white rounded-md hover:bg-primary-700">Add Workout</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
