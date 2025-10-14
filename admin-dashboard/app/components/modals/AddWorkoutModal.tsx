'use client';

import { useState, useEffect } from 'react';
import { db } from '@/lib/firebase';
import { collection, addDoc, getDocs, query, orderBy, Timestamp } from 'firebase/firestore';
import WorkoutAutocomplete from '../search/WorkoutAutocomplete';
import WorkoutConfigForm from '../forms/WorkoutConfigForm';

interface GlobalWorkout {
  id: string;
  name: string;
  type: 'Weight' | 'Timer';
  muscleGroups: string[];
  equipment: string[];
}

interface WorkoutConfig {
  baseWeight?: number;
  targetReps?: number;
  numSets: number;
  restTimer?: number;
  workoutDuration?: number;
}

interface AddWorkoutModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAdd: (workout: any) => void;
}

const MUSCLE_GROUPS = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Biceps', 'Triceps', 'Core', 'Glutes', 'Cardio'];
const EQUIPMENT = ['Barbell', 'Dumbbell', 'Bench', 'Bodyweight', 'Machine', 'Pull-up Bar', 'Dip Bar', 'None'];

export default function AddWorkoutModal({ isOpen, onClose, onAdd }: AddWorkoutModalProps) {
  const [activeTab, setActiveTab] = useState<'existing' | 'new'>('existing');
  const [selectedWorkout, setSelectedWorkout] = useState<GlobalWorkout | null>(null);
  const [workoutConfig, setWorkoutConfig] = useState<WorkoutConfig>({
    numSets: 4,
    baseWeight: 10,
    targetReps: 12,
    restTimer: 45,
  });

  // For "Create New" tab
  const [newWorkoutName, setNewWorkoutName] = useState('');
  const [newWorkoutType, setNewWorkoutType] = useState<'Weight' | 'Timer'>('Weight');
  const [selectedMuscleGroups, setSelectedMuscleGroups] = useState<string[]>([]);
  const [selectedEquipment, setSelectedEquipment] = useState<string[]>([]);

  // Fetch all global workouts
  const [workouts, setWorkouts] = useState<GlobalWorkout[]>([]);

  useEffect(() => {
    if (isOpen) {
      fetchWorkouts();
    }
  }, [isOpen]);

  const fetchWorkouts = async () => {
    try {
      const q = query(collection(db, 'global_workouts'), orderBy('name'));
      const snapshot = await getDocs(q);
      const workoutsData = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.name || '',
          type: (data.type || 'Weight') as 'Weight' | 'Timer',
          muscleGroups: data.muscleGroups || [],
          equipment: data.equipment || [],
        };
      });
      setWorkouts(workoutsData);
    } catch (error) {
      console.error('Error fetching workouts:', error);
    }
  };

  const handleClose = () => {
    // Reset state
    setActiveTab('existing');
    setSelectedWorkout(null);
    setNewWorkoutName('');
    setNewWorkoutType('Weight');
    setSelectedMuscleGroups([]);
    setSelectedEquipment([]);
    setWorkoutConfig({
      numSets: 4,
      baseWeight: 10,
      targetReps: 12,
      restTimer: 45,
    });
    onClose();
  };

  const handleWorkoutSelect = (workout: GlobalWorkout) => {
    setSelectedWorkout(workout);
    // Update config based on workout type
    if (workout.type === 'Timer') {
      setWorkoutConfig({
        numSets: 3,
        workoutDuration: 60,
      });
    } else {
      setWorkoutConfig({
        numSets: 4,
        baseWeight: 10,
        targetReps: 12,
        restTimer: 45,
      });
    }
  };

  const toggleMuscleGroup = (group: string) => {
    setSelectedMuscleGroups(prev =>
      prev.includes(group) ? prev.filter(g => g !== group) : [...prev, group]
    );
  };

  const toggleEquipment = (eq: string) => {
    setSelectedEquipment(prev =>
      prev.includes(eq) ? prev.filter(e => e !== eq) : [...prev, eq]
    );
  };

  const handleTypeChange = (type: 'Weight' | 'Timer') => {
    setNewWorkoutType(type);
    // Update config based on workout type
    if (type === 'Timer') {
      setWorkoutConfig({
        numSets: 3,
        workoutDuration: 60,
      });
    } else {
      setWorkoutConfig({
        numSets: 4,
        baseWeight: 10,
        targetReps: 12,
        restTimer: 45,
      });
    }
  };

  const handleAddToDay = async () => {
    if (activeTab === 'existing' && selectedWorkout) {
      onAdd({
        id: `workout-${Date.now()}`,
        ...selectedWorkout,
        config: workoutConfig,
      });
      handleClose();
    } else if (activeTab === 'new' && newWorkoutName) {
      // Check for duplicate workout name
      const trimmedName = newWorkoutName.trim();
      const duplicate = workouts.find(
        w => w.name.toLowerCase() === trimmedName.toLowerCase()
      );

      if (duplicate) {
        alert(`A workout named "${duplicate.name}" already exists. Please use a different name or select it from the "Select Existing" tab.`);
        return;
      }

      try {
        // Add new workout to global library
        const docRef = await addDoc(collection(db, 'global_workouts'), {
          name: trimmedName,
          type: newWorkoutType,
          muscleGroups: selectedMuscleGroups,
          equipment: selectedEquipment,
          searchKeywords: trimmedName.toLowerCase().split(' '),
          isActive: true,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        });

        // Add to day with config
        const newWorkout = {
          id: `workout-${Date.now()}`,
          name: trimmedName,
          type: newWorkoutType,
          muscleGroups: selectedMuscleGroups,
          equipment: selectedEquipment,
          config: workoutConfig,
        };
        onAdd(newWorkout);
        handleClose();
      } catch (error) {
        console.error('Error creating workout:', error);
        alert('Failed to create workout');
      }
    }
  };

  const handleCreateAndContinue = async () => {
    if (newWorkoutName) {
      // Check for duplicate workout name
      const trimmedName = newWorkoutName.trim();
      const duplicate = workouts.find(
        w => w.name.toLowerCase() === trimmedName.toLowerCase()
      );

      if (duplicate) {
        alert(`A workout named "${duplicate.name}" already exists. Please use a different name or select it from the "Select Existing" tab.`);
        return;
      }

      try {
        // Create in global library
        const docRef = await addDoc(collection(db, 'global_workouts'), {
          name: trimmedName,
          type: newWorkoutType,
          muscleGroups: selectedMuscleGroups,
          equipment: selectedEquipment,
          searchKeywords: trimmedName.toLowerCase().split(' '),
          isActive: true,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        });

        // Add to day with config
        const newWorkout = {
          id: docRef.id,
          name: trimmedName,
          type: newWorkoutType,
          muscleGroups: selectedMuscleGroups,
          equipment: selectedEquipment,
          config: workoutConfig,
        };
        onAdd(newWorkout);

        // Update local workouts list to include the newly created workout
        setWorkouts([...workouts, {
          id: docRef.id,
          name: trimmedName,
          type: newWorkoutType,
          muscleGroups: selectedMuscleGroups,
          equipment: selectedEquipment,
        }]);

        // Reset form but keep modal open
        setNewWorkoutName('');
        setSelectedMuscleGroups([]);
        setSelectedEquipment([]);
      } catch (error) {
        console.error('Error creating workout:', error);
        alert('Failed to create workout');
      }
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className="fixed inset-0 bg-black/30 backdrop-blur-sm transition-opacity"
          onClick={handleClose}
        ></div>
        <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-2xl p-8">
          {/* Header */}
          <div className="flex items-center justify-between mb-6">
            <div>
              <h3 className="text-[24px] font-bold text-[#000000]">Add Workout</h3>
              <p className="text-[14px] text-[#64748B] mt-1">Select an existing workout or create a new one</p>
            </div>
            <button
              onClick={handleClose}
              className="w-10 h-10 rounded-full hover:bg-[#F1F5F9] flex items-center justify-center transition-colors"
            >
              <svg className="w-6 h-6 text-[#64748B]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          {/* Tabs */}
          <div className="flex items-center bg-[#F1F5F9] rounded-lg p-1 mb-6">
            <button
              onClick={() => setActiveTab('existing')}
              className={`flex-1 px-4 py-2.5 text-[14px] font-medium rounded-lg transition-colors ${
                activeTab === 'existing'
                  ? 'bg-white text-[#000000] shadow-sm'
                  : 'text-[#64748B] hover:text-[#000000]'
              }`}
            >
              Select Existing
            </button>
            <button
              onClick={() => setActiveTab('new')}
              className={`flex-1 px-4 py-2.5 text-[14px] font-medium rounded-lg transition-colors ${
                activeTab === 'new'
                  ? 'bg-white text-[#000000] shadow-sm'
                  : 'text-[#64748B] hover:text-[#000000]'
              }`}
            >
              Create New
            </button>
          </div>

          {/* Tab Content */}
          <div className="space-y-6">
            {activeTab === 'existing' ? (
              <>
                {/* Search */}
                <div>
                  <label className="block text-[13px] font-semibold text-[#000000] mb-2">
                    Select Workout
                  </label>
                  <WorkoutAutocomplete workouts={workouts} onSelect={handleWorkoutSelect} />
                </div>

                {/* Configuration Form */}
                {selectedWorkout && (
                  <WorkoutConfigForm
                    workoutType={selectedWorkout.type}
                    config={workoutConfig}
                    onChange={setWorkoutConfig}
                  />
                )}
              </>
            ) : (
              <>
                {/* Workout Name */}
                <div>
                  <label htmlFor="workoutName" className="block text-[13px] font-semibold text-[#000000] mb-2">
                    Workout Name
                  </label>
                  <input
                    type="text"
                    id="workoutName"
                    value={newWorkoutName}
                    onChange={(e) => setNewWorkoutName(e.target.value)}
                    placeholder="e.g., Bench Press"
                    className="w-full px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-[#F8FAFC] focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
                  />
                </div>

                {/* Type */}
                <div>
                  <label className="block text-[13px] font-semibold text-[#000000] mb-3">Type</label>
                  <div className="flex items-center gap-6">
                    <label className="flex items-center cursor-pointer">
                      <input
                        type="radio"
                        value="Weight"
                        checked={newWorkoutType === 'Weight'}
                        onChange={() => handleTypeChange('Weight')}
                        className="w-4 h-4 text-[#000000] border-[#E2E8F0] focus:ring-[#2563EB]"
                      />
                      <span className="ml-2 text-[14px] text-[#000000]">Weight</span>
                    </label>
                    <label className="flex items-center cursor-pointer">
                      <input
                        type="radio"
                        value="Timer"
                        checked={newWorkoutType === 'Timer'}
                        onChange={() => handleTypeChange('Timer')}
                        className="w-4 h-4 text-[#000000] border-[#E2E8F0] focus:ring-[#2563EB]"
                      />
                      <span className="ml-2 text-[14px] text-[#000000]">Timer</span>
                    </label>
                  </div>
                </div>

                {/* Muscle Groups */}
                <div>
                  <label className="block text-[13px] font-semibold text-[#000000] mb-3">Muscle Groups</label>
                  <div className="flex flex-wrap gap-2">
                    {MUSCLE_GROUPS.map((group) => (
                      <button
                        key={group}
                        onClick={() => toggleMuscleGroup(group)}
                        className={`px-3 py-1.5 text-[13px] font-medium rounded-full transition-colors ${
                          selectedMuscleGroups.includes(group)
                            ? 'bg-[#000000] text-white'
                            : 'bg-[#F1F5F9] text-[#334155] hover:bg-[#E2E8F0]'
                        }`}
                      >
                        {group}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Equipment */}
                <div>
                  <label className="block text-[13px] font-semibold text-[#000000] mb-3">Equipment</label>
                  <div className="flex flex-wrap gap-2">
                    {EQUIPMENT.map((eq) => (
                      <button
                        key={eq}
                        onClick={() => toggleEquipment(eq)}
                        className={`px-3 py-1.5 text-[13px] font-medium rounded-full transition-colors ${
                          selectedEquipment.includes(eq)
                            ? 'bg-[#000000] text-white'
                            : 'bg-[#F1F5F9] text-[#334155] hover:bg-[#E2E8F0]'
                        }`}
                      >
                        {eq}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Workout Configuration */}
                <WorkoutConfigForm
                  workoutType={newWorkoutType}
                  config={workoutConfig}
                  onChange={setWorkoutConfig}
                />

                {/* Create & Continue Button */}
                <button
                  onClick={handleCreateAndContinue}
                  disabled={!newWorkoutName}
                  className="w-full px-4 py-3 bg-[#0F172A] text-white text-[14px] font-medium rounded-lg hover:bg-[#1E293B] transition-colors disabled:bg-[#E2E8F0] disabled:text-[#94A3B8] disabled:cursor-not-allowed flex items-center justify-center gap-2"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                  </svg>
                  Create Workout & Continue
                </button>
              </>
            )}
          </div>

          {/* Footer Actions */}
          <div className="flex items-center justify-end gap-3 mt-8 pt-6 border-t border-[#E2E8F0]">
            <button
              onClick={handleClose}
              className="px-6 py-2.5 text-[14px] font-medium text-[#64748B] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleAddToDay}
              disabled={
                (activeTab === 'existing' && !selectedWorkout) ||
                (activeTab === 'new' && !newWorkoutName)
              }
              className="px-6 py-2.5 text-[14px] font-medium text-white bg-[#64748B] rounded-lg hover:bg-[#475569] transition-colors disabled:bg-[#E2E8F0] disabled:text-[#94A3B8] disabled:cursor-not-allowed"
            >
              Add to Day
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
