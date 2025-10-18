'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { db } from '@/lib/firebase';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  addDoc,
  deleteDoc,
  Timestamp,
} from 'firebase/firestore';
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  DragEndEvent,
} from '@dnd-kit/core';
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import AddWorkoutModal from '@/app/components/modals/AddWorkoutModal';
import BulkEditTargetRepsModal from '@/app/components/modals/BulkEditTargetRepsModal';
import { useToast } from '@/app/context/ToastContext';
import { useConfirm } from '@/app/hooks/useConfirm';

interface Workout {
  id: string;
  globalWorkoutId: string;  // Reference to global_workouts collection
  // Display data (fetched from global_workouts, not stored in Firestore)
  name?: string;
  type?: 'Weight' | 'Timer';
  muscleGroups?: string[];
  equipment?: string[];
  order?: number;
  config: {
    baseWeight?: number;
    targetReps?: string;
    numSets: number;
    restTimer?: number;
    workoutDuration?: number;
  };
}

interface Day {
  id: string;
  name: string;
  workouts: Workout[];
}

interface Week {
  id: string;
  number: number;
  days: Day[];
}

interface WorkoutPlan {
  id: string;
  name: string;
  description: string;
  weeks: Week[];
}

interface SortableWorkoutItemProps {
  workout: Workout;
  index: number;
  onEdit: () => void;
  onDelete: () => void;
}

function SortableWorkoutItem({ workout, index, onEdit, onDelete }: SortableWorkoutItemProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: workout.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className="flex items-start gap-2"
    >
      <button
        {...attributes}
        {...listeners}
        className="flex-shrink-0 mt-1 cursor-grab active:cursor-grabbing p-1 hover:bg-gray-100 rounded transition-colors"
      >
        <svg className="w-4 h-4 text-[#94A3B8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <circle cx="9" cy="5" r="1" fill="currentColor" />
          <circle cx="9" cy="12" r="1" fill="currentColor" />
          <circle cx="9" cy="19" r="1" fill="currentColor" />
          <circle cx="15" cy="5" r="1" fill="currentColor" />
          <circle cx="15" cy="12" r="1" fill="currentColor" />
          <circle cx="15" cy="19" r="1" fill="currentColor" />
        </svg>
      </button>
      <div className="flex-1 min-w-0">
        <div className="text-[13px] font-medium text-[#000000]">
          {index + 1}. {workout.name}
        </div>
        <div className="text-[12px] text-[#64748B] mt-0.5">
          {workout.type === 'Weight' ? (
            <>
              {workout.config.numSets} x {workout.config.targetReps} @ {workout.config.baseWeight}lbs
            </>
          ) : (
            <>
              {workout.config.numSets} x {workout.config.workoutDuration}s
            </>
          )}
        </div>
      </div>
      <div className="flex items-center gap-1">
        <button
          onClick={onEdit}
          className="flex-shrink-0 p-1 text-[#64748B] hover:text-[#2563EB] transition-colors"
          title="Edit Workout"
        >
          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button
          onClick={onDelete}
          className="flex-shrink-0 p-1 text-[#64748B] hover:text-[#DC2626] transition-colors"
          title="Delete Workout"
        >
          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>
  );
}

export default function EditPlanPage() {
  const router = useRouter();
  const params = useParams();
  const planId = params.id as string;
  const toast = useToast();
  const { confirm, ConfirmDialog } = useConfirm();

  const [plan, setPlan] = useState<WorkoutPlan>({
    id: planId === 'new' ? '' : planId,
    name: '',
    description: '',
    weeks: [],
  });

  const [activeWeekIndex, setActiveWeekIndex] = useState(0);
  const [isAddWorkoutModalOpen, setIsAddWorkoutModalOpen] = useState(false);
  const [isBulkEditRepsOpen, setIsBulkEditRepsOpen] = useState(false);
  const [selectedDayId, setSelectedDayId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [editingWorkout, setEditingWorkout] = useState<Workout | null>(null);
  const [modalMode, setModalMode] = useState<'add' | 'edit'>('add');

  // Track original plan state for change detection
  const originalPlanRef = useRef<WorkoutPlan | null>(null);

  // Ref for file input
  const fileInputRef = useRef<HTMLInputElement>(null);

  const sensors = useSensors(
    useSensor(PointerSensor),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  useEffect(() => {
    if (planId !== 'new') {
      loadPlanFromFirebase();
    }
  }, [planId]);

  const loadPlanFromFirebase = async () => {
    try {
      setLoading(true);

      // Fetch plan document
      const planDoc = await getDoc(doc(db, 'workout_plans', planId));
      if (!planDoc.exists()) {
        toast.error('Plan not found');
        router.push('/workout-plans');
        return;
      }

      const planData = planDoc.data();

      // Fetch weeks subcollection
      const weeksSnapshot = await getDocs(collection(db, 'workout_plans', planId, 'weeks'));
      const weeks = await Promise.all(
        weeksSnapshot.docs.map(async (weekDoc) => {
          const weekData = weekDoc.data();

          // Fetch days subcollection for this week
          const daysSnapshot = await getDocs(
            collection(db, 'workout_plans', planId, 'weeks', weekDoc.id, 'days')
          );

          const days = await Promise.all(
            daysSnapshot.docs.map(async (dayDoc) => {
              const dayData = dayDoc.data();

              // Fetch workouts subcollection for this day
              const workoutsSnapshot = await getDocs(
                collection(db, 'workout_plans', planId, 'weeks', weekDoc.id, 'days', dayDoc.id, 'workouts')
              );

              // Fetch global workout data for all workouts in this day
              const workouts = await Promise.all(
                workoutsSnapshot.docs.map(async (workoutDoc) => {
                  const workoutData = workoutDoc.data();

                  // Fetch global workout data if globalWorkoutId exists
                  let globalWorkoutData = null;
                  if (workoutData.globalWorkoutId) {
                    const globalWorkoutDoc = await getDoc(doc(db, 'global_workouts', workoutData.globalWorkoutId));
                    if (globalWorkoutDoc.exists()) {
                      globalWorkoutData = globalWorkoutDoc.data();
                    }
                  }

                  return {
                    id: workoutDoc.id,
                    globalWorkoutId: workoutData.globalWorkoutId || '',
                    // Display data from global workout (or fallback to legacy data)
                    name: globalWorkoutData?.name || workoutData.name || '',
                    type: (globalWorkoutData?.type || workoutData.type || 'Weight') as 'Weight' | 'Timer',
                    muscleGroups: globalWorkoutData?.muscleGroups || workoutData.muscleGroups || [],
                    equipment: globalWorkoutData?.equipment || workoutData.equipment || [],
                    order: workoutData.order || 0,
                    config: {
                      baseWeight: workoutData.baseWeight,
                      targetReps: workoutData.targetReps,
                      numSets: workoutData.numSets || 0,
                      restTimer: workoutData.restTimerSeconds,
                      workoutDuration: workoutData.workoutDurationSeconds,
                    },
                  };
                })
              );

              // Sort by order
              workouts.sort((a, b) => (a.order || 0) - (b.order || 0));

              return {
                id: dayDoc.id,
                name: dayData.name || '',
                workouts,
              };
            })
          );

          return {
            id: weekDoc.id,
            number: weekData.weekNumber || 0,
            days,
          };
        })
      );

      const loadedPlan = {
        id: planDoc.id,
        name: planData.name || '',
        description: planData.description || '',
        weeks,
      };

      setPlan(loadedPlan);
      // Store deep copy of original plan for change detection
      originalPlanRef.current = JSON.parse(JSON.stringify(loadedPlan));
    } catch (error) {
      console.error('Error loading plan:', error);
      toast.error('Failed to load plan');
    } finally {
      setLoading(false);
    }
  };

  const handleAddWeek = () => {
    const newWeek: Week = {
      id: `week-${Date.now()}`,
      number: plan.weeks.length + 1,
      days: [],
    };
    setPlan({ ...plan, weeks: [...plan.weeks, newWeek] });
    setActiveWeekIndex(plan.weeks.length);
  };

  const handleCopyWeek = () => {
    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return;

    const copiedWeek: Week = {
      id: `week-${Date.now()}`,
      number: plan.weeks.length + 1,
      days: currentWeek.days.map(day => ({
        ...day,
        id: `day-${Date.now()}-${day.id}`,
        name: day.name, // Keep original name without "(Copy)"
      })),
    };
    setPlan({ ...plan, weeks: [...plan.weeks, copiedWeek] });
  };

  const handleDeleteWeek = async () => {
    if (plan.weeks.length <= 1) {
      toast.warning('Cannot delete the last week');
      return;
    }

    const confirmed = await confirm({
      title: 'Delete Week',
      message: 'Are you sure you want to delete this week?',
      confirmLabel: 'Delete',
      variant: 'danger',
    });

    if (!confirmed) return;

    const newWeeks = plan.weeks.filter((_, idx) => idx !== activeWeekIndex);
    setPlan({ ...plan, weeks: newWeeks });
    setActiveWeekIndex(Math.max(0, activeWeekIndex - 1));
  };

  const getUniqueTargetReps = (): string[] => {
    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return [];

    const uniqueValues = new Set<string>();
    currentWeek.days.forEach(day => {
      day.workouts.forEach(workout => {
        // Only include weight workouts with targetReps
        if (workout.type === 'Weight' && workout.config.targetReps) {
          uniqueValues.add(workout.config.targetReps);
        }
      });
    });

    return Array.from(uniqueValues).sort();
  };

  const handleBulkUpdateTargetReps = (mapping: Record<string, string>) => {
    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return;

    const updatedWeeks = [...plan.weeks];
    const updatedDays = currentWeek.days.map(day => ({
      ...day,
      workouts: day.workouts.map(workout => {
        // Only update weight workouts where a mapping exists
        if (workout.type === 'Weight' && workout.config.targetReps && mapping[workout.config.targetReps]) {
          return {
            ...workout,
            config: {
              ...workout.config,
              targetReps: mapping[workout.config.targetReps],
            },
          };
        }
        return workout;
      }),
    }));

    updatedWeeks[activeWeekIndex] = {
      ...currentWeek,
      days: updatedDays,
    };

    setPlan({ ...plan, weeks: updatedWeeks });
  };

  const handleAddDay = () => {
    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return;

    const newDay: Day = {
      id: `day-${Date.now()}`,
      name: `Day ${currentWeek.days.length + 1}`,
      workouts: [],
    };

    const updatedWeeks = [...plan.weeks];
    updatedWeeks[activeWeekIndex] = {
      ...currentWeek,
      days: [...currentWeek.days, newDay],
    };
    setPlan({ ...plan, weeks: updatedWeeks });
  };


  const handleDeleteDay = async (dayId: string) => {
    const confirmed = await confirm({
      title: 'Delete Day',
      message: 'Are you sure you want to delete this day?',
      confirmLabel: 'Delete',
      variant: 'danger',
    });

    if (!confirmed) return;

    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return;

    const updatedWeeks = [...plan.weeks];
    updatedWeeks[activeWeekIndex] = {
      ...currentWeek,
      days: currentWeek.days.filter(d => d.id !== dayId),
    };
    setPlan({ ...plan, weeks: updatedWeeks });
  };

  const handleAddWorkout = (dayId: string) => {
    setSelectedDayId(dayId);
    setModalMode('add');
    setEditingWorkout(null);
    setIsAddWorkoutModalOpen(true);
  };

  const handleEditWorkout = (dayId: string, workout: Workout) => {
    setSelectedDayId(dayId);
    setEditingWorkout(workout);
    setModalMode('edit');
    setIsAddWorkoutModalOpen(true);
  };

  const handleWorkoutAdded = (workout: any) => {
    if (!selectedDayId) return;

    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return;

    const updatedWeeks = [...plan.weeks];
    const dayIndex = currentWeek.days.findIndex(d => d.id === selectedDayId);
    if (dayIndex === -1) return;

    const updatedDays = [...currentWeek.days];

    // Check if we're editing or adding
    if (modalMode === 'edit' && editingWorkout) {
      // Replace the existing workout
      updatedDays[dayIndex] = {
        ...updatedDays[dayIndex],
        workouts: updatedDays[dayIndex].workouts.map(w =>
          w.id === editingWorkout.id ? workout : w
        ),
      };
    } else {
      // Add new workout
      updatedDays[dayIndex] = {
        ...updatedDays[dayIndex],
        workouts: [...updatedDays[dayIndex].workouts, workout],
      };
    }

    updatedWeeks[activeWeekIndex] = {
      ...currentWeek,
      days: updatedDays,
    };

    setPlan({ ...plan, weeks: updatedWeeks });
  };

  const handleDeleteWorkout = async (dayId: string, workoutId: string) => {
    const confirmed = await confirm({
      title: 'Delete Workout',
      message: 'Are you sure you want to delete this workout?',
      confirmLabel: 'Delete',
      variant: 'danger',
    });

    if (!confirmed) return;

    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return;

    const updatedWeeks = [...plan.weeks];
    const dayIndex = currentWeek.days.findIndex(d => d.id === dayId);
    if (dayIndex === -1) return;

    const updatedDays = [...currentWeek.days];
    updatedDays[dayIndex] = {
      ...updatedDays[dayIndex],
      workouts: updatedDays[dayIndex].workouts.filter(w => w.id !== workoutId),
    };

    updatedWeeks[activeWeekIndex] = {
      ...currentWeek,
      days: updatedDays,
    };

    setPlan({ ...plan, weeks: updatedWeeks });
  };

  const handleDragEnd = (event: DragEndEvent, dayId: string) => {
    const { active, over } = event;

    if (!over || active.id === over.id) return;

    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return;

    const dayIndex = currentWeek.days.findIndex(d => d.id === dayId);
    if (dayIndex === -1) return;

    const day = currentWeek.days[dayIndex];
    const oldIndex = day.workouts.findIndex(w => w.id === active.id);
    const newIndex = day.workouts.findIndex(w => w.id === over.id);

    if (oldIndex !== -1 && newIndex !== -1) {
      // Reorder workouts AND update their order property
      const reorderedWorkouts = arrayMove(day.workouts, oldIndex, newIndex)
        .map((workout, index) => ({
          ...workout,
          order: index + 1  // Update order property to match new position
        }));

      const updatedWeeks = [...plan.weeks];
      const updatedDays = [...currentWeek.days];
      updatedDays[dayIndex] = {
        ...day,
        workouts: reorderedWorkouts,
      };

      updatedWeeks[activeWeekIndex] = {
        ...currentWeek,
        days: updatedDays,
      };

      setPlan({ ...plan, weeks: updatedWeeks });
    }
  };

  // Helper functions for change detection
  const hasWorkoutChanged = (w1: Workout, w2: Workout): boolean => {
    return (
      w1.globalWorkoutId !== w2.globalWorkoutId ||  // Check if global workout reference changed
      w1.order !== w2.order ||
      w1.config.baseWeight !== w2.config.baseWeight ||
      w1.config.targetReps !== w2.config.targetReps ||
      w1.config.numSets !== w2.config.numSets ||
      w1.config.restTimer !== w2.config.restTimer ||
      w1.config.workoutDuration !== w2.config.workoutDuration
      // Note: Don't compare name, type, muscleGroups, equipment as they're fetched from global_workouts
    );
  };

  const hasDayChanged = (d1: Day, d2: Day): boolean => {
    if (d1.name !== d2.name) return true;
    if (d1.workouts.length !== d2.workouts.length) return true;

    // Check if any workout changed
    for (let i = 0; i < d1.workouts.length; i++) {
      const originalWorkout = d2.workouts.find(w => w.id === d1.workouts[i].id);
      if (!originalWorkout || hasWorkoutChanged(d1.workouts[i], originalWorkout)) {
        return true;
      }
    }
    return false;
  };

  const hasWeekChanged = (w1: Week, w2: Week): boolean => {
    if (w1.number !== w2.number) return true;
    if (w1.days.length !== w2.days.length) return true;

    // Check if any day changed
    for (let i = 0; i < w1.days.length; i++) {
      const originalDay = w2.days.find(d => d.id === w1.days[i].id);
      if (!originalDay || hasDayChanged(w1.days[i], originalDay)) {
        return true;
      }
    }
    return false;
  };

  const handleSave = async () => {
    try {
      if (!plan.name.trim()) {
        toast.warning('Please enter a plan name');
        return;
      }

      setLoading(true);

      const isNewPlan = plan.id === '' || planId === 'new';
      let finalPlanId = plan.id;

      // Save or update plan document
      if (isNewPlan) {
        const planRef = await addDoc(collection(db, 'workout_plans'), {
          name: plan.name,
          description: plan.description,
          totalWeeks: plan.weeks.length,
          isActive: true,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        });
        finalPlanId = planRef.id;
      } else {
        // Only update plan document if changed
        const originalPlan = originalPlanRef.current;
        if (
          !originalPlan ||
          originalPlan.name !== plan.name ||
          originalPlan.description !== plan.description ||
          originalPlan.weeks.length !== plan.weeks.length
        ) {
          await updateDoc(doc(db, 'workout_plans', finalPlanId), {
            name: plan.name,
            description: plan.description,
            totalWeeks: plan.weeks.length,
            updatedAt: Timestamp.now(),
          });
        }

        // CLEANUP: Delete orphaned documents that were removed locally
        // Fetch existing weeks from Firestore
        const existingWeeksSnapshot = await getDocs(
          collection(db, 'workout_plans', finalPlanId, 'weeks')
        );

        const localWeekIds = new Set(plan.weeks.map(w => w.id));

        // Delete orphaned weeks
        for (const weekDoc of existingWeeksSnapshot.docs) {
          if (!localWeekIds.has(weekDoc.id)) {
            // Week was deleted locally, remove from Firestore
            await deleteDoc(doc(db, 'workout_plans', finalPlanId, 'weeks', weekDoc.id));
          }
        }

        // For each week in local state, check for orphaned days and workouts
        for (const week of plan.weeks) {
          const existingDaysSnapshot = await getDocs(
            collection(db, 'workout_plans', finalPlanId, 'weeks', week.id, 'days')
          );

          const localDayIds = new Set(week.days.map(d => d.id));

          // Delete orphaned days
          for (const dayDoc of existingDaysSnapshot.docs) {
            if (!localDayIds.has(dayDoc.id)) {
              // Day was deleted locally, remove from Firestore
              await deleteDoc(
                doc(db, 'workout_plans', finalPlanId, 'weeks', week.id, 'days', dayDoc.id)
              );
            }
          }

          // For each day in local state, check for orphaned workouts
          for (const day of week.days) {
            const existingWorkoutsSnapshot = await getDocs(
              collection(db, 'workout_plans', finalPlanId, 'weeks', week.id, 'days', day.id, 'workouts')
            );

            const localWorkoutIds = new Set(day.workouts.map(w => w.id));

            // Delete orphaned workouts
            for (const workoutDoc of existingWorkoutsSnapshot.docs) {
              if (!localWorkoutIds.has(workoutDoc.id)) {
                // Workout was deleted locally, remove from Firestore
                await deleteDoc(
                  doc(
                    db,
                    'workout_plans',
                    finalPlanId,
                    'weeks',
                    week.id,
                    'days',
                    day.id,
                    'workouts',
                    workoutDoc.id
                  )
                );
              }
            }
          }
        }
      }

      // Save weeks, days, and workouts (nested subcollections)
      const originalPlan = originalPlanRef.current;

      for (const week of plan.weeks) {
        const weekRef = doc(db, 'workout_plans', finalPlanId, 'weeks', week.id);

        // Check if week is new or changed
        const originalWeek = originalPlan?.weeks.find(w => w.id === week.id);
        const isNewWeek = !originalWeek;
        const weekChanged = originalWeek && hasWeekChanged(week, originalWeek);

        if (isNewWeek) {
          // New week: use setDoc
          await setDoc(weekRef, {
            weekNumber: week.number,
            name: `Week ${week.number}`,
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          });
        } else if (weekChanged && week.number !== originalWeek.number) {
          // Week metadata changed: update only
          await updateDoc(weekRef, {
            weekNumber: week.number,
            name: `Week ${week.number}`,
            updatedAt: Timestamp.now(),
          });
        }

        // Save days for this week
        for (const day of week.days) {
          const dayRef = doc(db, 'workout_plans', finalPlanId, 'weeks', week.id, 'days', day.id);

          // Check if day is new or changed
          const originalDay = originalWeek?.days.find(d => d.id === day.id);
          const isNewDay = !originalDay;
          const dayChanged = originalDay && hasDayChanged(day, originalDay);

          if (isNewDay) {
            // New day: use setDoc
            await setDoc(dayRef, {
              dayNumber: day.name.match(/\d+/)?.[0] || '1',
              name: day.name,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            });
          } else if (dayChanged && day.name !== originalDay.name) {
            // Day name changed: update only
            await updateDoc(dayRef, {
              dayNumber: day.name.match(/\d+/)?.[0] || '1',
              name: day.name,
              updatedAt: Timestamp.now(),
            });
          }

          // Save workouts for this day
          for (const workout of day.workouts) {
            const workoutRef = doc(
              db,
              'workout_plans',
              finalPlanId,
              'weeks',
              week.id,
              'days',
              day.id,
              'workouts',
              workout.id
            );

            // Check if workout is new or changed
            const originalWorkout = originalDay?.workouts.find(w => w.id === workout.id);
            const isNewWorkout = !originalWorkout;
            const workoutChanged = originalWorkout && hasWorkoutChanged(workout, originalWorkout);

            // Calculate order
            const order = day.workouts.indexOf(workout) + 1;

            if (isNewWorkout) {
              // New workout: use setDoc (save only globalWorkoutId + config)
              await setDoc(workoutRef, {
                globalWorkoutId: workout.globalWorkoutId,  // Reference to global workout
                order,
                numSets: workout.config.numSets,
                targetReps: workout.config.targetReps || null,
                baseWeight: workout.config.baseWeight || null,
                restTimerSeconds: workout.config.restTimer || null,
                workoutDurationSeconds: workout.config.workoutDuration || null,
                createdAt: Timestamp.now(),
                updatedAt: Timestamp.now(),
              });
            } else if (workoutChanged) {
              // Workout changed: update only changed fields (no name, type, muscleGroups, equipment)
              await updateDoc(workoutRef, {
                globalWorkoutId: workout.globalWorkoutId,  // Reference to global workout
                order,
                numSets: workout.config.numSets,
                targetReps: workout.config.targetReps || null,
                baseWeight: workout.config.baseWeight || null,
                restTimerSeconds: workout.config.restTimer || null,
                workoutDurationSeconds: workout.config.workoutDuration || null,
                updatedAt: Timestamp.now(),
              });
            }
          }
        }
      }

      toast.success('Plan saved successfully!');

      // Update original plan ref for next save comparison
      const updatedPlan = { ...plan, id: finalPlanId };
      originalPlanRef.current = JSON.parse(JSON.stringify(updatedPlan));

      // Redirect to edit page if it was a new plan
      if (isNewPlan) {
        router.push(`/workout-plans/${finalPlanId}`);
      }
    } catch (error) {
      console.error('Error saving plan:', error);
      toast.error('Failed to save plan. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleExportJSON = () => {
    const dataStr = JSON.stringify(plan, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${plan.name || 'workout-plan'}.json`;
    link.click();
  };

  const validateImportedPlan = (data: any): { valid: boolean; error?: string; plan?: WorkoutPlan } => {
    try {
      // Check if data is an object
      if (!data || typeof data !== 'object') {
        return { valid: false, error: 'Invalid JSON structure' };
      }

      // Check required fields
      if (!data.name || typeof data.name !== 'string') {
        return { valid: false, error: 'Missing required field: name' };
      }

      if (!Array.isArray(data.weeks)) {
        return { valid: false, error: 'Missing required field: weeks (must be an array)' };
      }

      // Validate weeks
      for (let weekIdx = 0; weekIdx < data.weeks.length; weekIdx++) {
        const week = data.weeks[weekIdx];

        if (!week || typeof week !== 'object') {
          return { valid: false, error: `Invalid week structure at index ${weekIdx}` };
        }

        if (typeof week.number !== 'number') {
          return { valid: false, error: `Invalid week number at index ${weekIdx}` };
        }

        if (!Array.isArray(week.days)) {
          return { valid: false, error: `Week ${weekIdx + 1}: days must be an array` };
        }

        // Validate days
        for (let dayIdx = 0; dayIdx < week.days.length; dayIdx++) {
          const day = week.days[dayIdx];

          if (!day || typeof day !== 'object') {
            return { valid: false, error: `Week ${weekIdx + 1}: Invalid day structure at index ${dayIdx}` };
          }

          if (!day.name || typeof day.name !== 'string') {
            return { valid: false, error: `Week ${weekIdx + 1}, Day ${dayIdx + 1}: Missing day name` };
          }

          if (!Array.isArray(day.workouts)) {
            return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}: workouts must be an array` };
          }

          // Validate workouts
          for (let workoutIdx = 0; workoutIdx < day.workouts.length; workoutIdx++) {
            const workout = day.workouts[workoutIdx];

            if (!workout || typeof workout !== 'object') {
              return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, Workout ${workoutIdx + 1}: Invalid workout structure` };
            }

            if (!workout.name || typeof workout.name !== 'string') {
              return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, Workout ${workoutIdx + 1}: Missing workout name` };
            }

            if (workout.type !== 'Weight' && workout.type !== 'Timer') {
              return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, ${workout.name}: Invalid type. Must be 'Weight' or 'Timer'` };
            }

            if (!Array.isArray(workout.muscleGroups)) {
              return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, ${workout.name}: muscleGroups must be an array` };
            }

            if (!Array.isArray(workout.equipment)) {
              return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, ${workout.name}: equipment must be an array` };
            }

            if (!workout.config || typeof workout.config !== 'object') {
              return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, ${workout.name}: Missing config object` };
            }

            if (typeof workout.config.numSets !== 'number') {
              return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, ${workout.name}: config.numSets must be a number` };
            }

            // Validate based on workout type
            if (workout.type === 'Weight') {
              if (workout.config.targetReps === undefined) {
                return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, ${workout.name}: Weight workouts require targetReps` };
              }
            } else if (workout.type === 'Timer') {
              if (typeof workout.config.workoutDuration !== 'number') {
                return { valid: false, error: `Week ${weekIdx + 1}, ${day.name}, ${workout.name}: Timer workouts require workoutDuration (number)` };
              }
            }
          }
        }
      }

      // Generate new IDs to avoid collisions
      const timestamp = Date.now();
      const importedPlan: WorkoutPlan = {
        id: '', // Will be assigned on save
        name: data.name,
        description: data.description || '',
        weeks: data.weeks.map((week: any, weekIdx: number) => ({
          id: `week-${timestamp}-${weekIdx}`,
          number: week.number,
          days: week.days.map((day: any, dayIdx: number) => ({
            id: `day-${timestamp}-${weekIdx}-${dayIdx}`,
            name: day.name,
            workouts: day.workouts.map((workout: any, workoutIdx: number) => ({
              id: `workout-${timestamp}-${weekIdx}-${dayIdx}-${workoutIdx}`,
              name: workout.name,
              type: workout.type,
              muscleGroups: workout.muscleGroups || [],
              equipment: workout.equipment || [],
              order: workout.order || workoutIdx + 1,
              config: {
                baseWeight: workout.config.baseWeight,
                targetReps: workout.config.targetReps,
                numSets: workout.config.numSets,
                restTimer: workout.config.restTimer,
                workoutDuration: workout.config.workoutDuration,
              },
            })),
          })),
        })),
      };

      return { valid: true, plan: importedPlan };
    } catch (error) {
      return { valid: false, error: 'Failed to parse JSON file' };
    }
  };

  const handleImportJSON = () => {
    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  const handleFileSelected = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    // Check file size (5MB limit)
    const maxSize = 5 * 1024 * 1024; // 5MB
    if (file.size > maxSize) {
      toast.error('File size exceeds 5MB limit');
      return;
    }

    // Check file type
    if (!file.name.endsWith('.json')) {
      toast.error('Please select a JSON file');
      return;
    }

    try {
      const fileContent = await file.text();
      const jsonData = JSON.parse(fileContent);

      // Validate the imported data
      const validation = validateImportedPlan(jsonData);

      if (!validation.valid) {
        toast.error(`Import failed: ${validation.error}`);
        return;
      }

      if (!validation.plan) {
        toast.error('Import failed: Invalid plan data');
        return;
      }

      // Show confirmation dialog
      const confirmed = await confirm({
        title: 'Import Workout Plan',
        message: `This will replace the current plan with "${validation.plan.name}" containing ${validation.plan.weeks.length} week(s). Continue?`,
        confirmLabel: 'Import',
        variant: 'default',
      });

      if (!confirmed) {
        // Reset file input
        if (fileInputRef.current) {
          fileInputRef.current.value = '';
        }
        return;
      }

      // Load the imported plan into state
      setPlan(validation.plan);
      setActiveWeekIndex(0);

      // Clear original plan ref so changes are detected
      originalPlanRef.current = null;

      toast.success(`Successfully imported "${validation.plan.name}". Click "Save Plan" to persist changes.`);

      // Reset file input
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    } catch (error) {
      console.error('Error importing JSON:', error);
      toast.error('Failed to import JSON file. Please check the file format.');

      // Reset file input
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const currentWeek = plan.weeks[activeWeekIndex];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center space-y-4">
          <div className="w-16 h-16 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
          <p className="text-gray-500 font-medium">Loading plan...</p>
        </div>
      </div>
    );
  }

  return (
    <>
      <ConfirmDialog />
      <div className="space-y-6 pb-16">
      {/* Back Button */}
      <button
        onClick={() => router.push('/workout-plans')}
        className="flex items-center text-[14px] text-[#64748B] hover:text-[#000000] transition-colors"
      >
        <svg className="w-5 h-5 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to Plans
      </button>

      {/* Hidden file input for JSON import */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".json,application/json"
        onChange={handleFileSelected}
        className="hidden"
      />

      {/* Plan Overview */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] p-8">
        <div className="flex items-start justify-between mb-6">
          <div>
            <h2 className="text-[20px] font-bold text-[#000000]">Plan Overview</h2>
            <p className="text-[14px] text-[#64748B] mt-1">Configure your workout plan details</p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={handleImportJSON}
              className="px-4 py-2 text-[14px] font-medium text-[#000000] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors flex items-center gap-2"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
              </svg>
              Import JSON
            </button>
            <button
              onClick={handleExportJSON}
              className="px-4 py-2 text-[14px] font-medium text-[#000000] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors flex items-center gap-2"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
              Export JSON
            </button>
            <button
              onClick={handleSave}
              className="px-4 py-2.5 bg-[#0F172A] text-white text-[14px] font-medium rounded-lg hover:bg-[#1E293B] transition-colors flex items-center gap-2"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
              Save Plan
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label htmlFor="planName" className="block text-[13px] font-semibold text-[#000000] mb-2">
              Plan Name
            </label>
            <input
              type="text"
              id="planName"
              value={plan.name}
              onChange={(e) => setPlan({ ...plan, name: e.target.value })}
              placeholder="Beginner Strength Training"
              className="w-full px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-[#F8FAFC] focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
            />
          </div>

          <div>
            <label className="block text-[13px] font-semibold text-[#000000] mb-2">
              Total Weeks
            </label>
            <div className="px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-[#F8FAFC] text-[#64748B]">
              {plan.weeks.length}
            </div>
            <p className="text-[12px] text-[#94A3B8] mt-1">Weeks are created using the "Add New Week" button</p>
          </div>

          <div className="md:col-span-2">
            <label htmlFor="planDescription" className="block text-[13px] font-semibold text-[#000000] mb-2">
              Description
            </label>
            <textarea
              id="planDescription"
              rows={3}
              value={plan.description}
              onChange={(e) => setPlan({ ...plan, description: e.target.value })}
              placeholder="A comprehensive 8-week program designed for beginners to build foundational strength"
              className="w-full px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-[#F8FAFC] focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent resize-none"
            />
          </div>
        </div>
      </div>

      {/* Week Structure */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] p-8">
        <div className="flex items-start justify-between mb-6">
          <div>
            <h2 className="text-[20px] font-bold text-[#000000]">Week Structure</h2>
            <p className="text-[14px] text-[#64748B] mt-1">Build your weekly workout schedule</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handleCopyWeek}
              disabled={!currentWeek}
              className="px-4 py-2 text-[14px] font-medium text-[#000000] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              Copy Week
            </button>
            <button
              onClick={handleAddWeek}
              className="px-4 py-2.5 bg-[#0F172A] text-white text-[14px] font-medium rounded-lg hover:bg-[#1E293B] transition-colors flex items-center gap-2"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
              </svg>
              Add New Week
            </button>
          </div>
        </div>

        {/* Week Tabs */}
        {plan.weeks.length > 0 && (
          <div className="mb-6">
            <div className="flex items-center gap-2 overflow-x-auto pb-2">
              {plan.weeks.map((week, idx) => (
                <button
                  key={week.id}
                  onClick={() => setActiveWeekIndex(idx)}
                  className={`px-6 py-2.5 text-[14px] font-medium rounded-lg whitespace-nowrap transition-colors ${
                    activeWeekIndex === idx
                      ? 'bg-[#F1F5F9] text-[#000000]'
                      : 'text-[#64748B] hover:text-[#000000]'
                  }`}
                >
                  Week {week.number}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Current Week Content */}
        {currentWeek ? (
          <div>
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="text-[16px] font-semibold text-[#000000]">Week {currentWeek.number}</h3>
                <p className="text-[13px] text-[#64748B] mt-1">{currentWeek.days.length} days configured</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setIsBulkEditRepsOpen(true)}
                  className="px-4 py-2 text-[14px] font-medium text-[#000000] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors flex items-center gap-2"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                  Bulk Edit Reps
                </button>
                <button
                  onClick={handleDeleteWeek}
                  className="px-4 py-2 text-[14px] font-medium text-[#DC2626] bg-white border border-[#FCA5A5] rounded-lg hover:bg-[#FEE2E2] transition-colors flex items-center gap-2"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                  Delete Week
                </button>
              </div>
            </div>

            {/* Days Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {currentWeek.days.map((day) => (
                <div key={day.id} className="bg-white rounded-lg border border-[#E2E8F0] overflow-hidden">
                  {/* Day Header */}
                  <div className="px-4 py-3 bg-[#F8FAFC] border-b border-[#E2E8F0] flex items-center justify-between">
                    <h4 className="text-[14px] font-semibold text-[#000000]">{day.name}</h4>
                    <button
                      onClick={() => handleDeleteDay(day.id)}
                      className="p-1 text-[#64748B] hover:text-[#DC2626] transition-colors"
                      title="Delete Day"
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>

                  {/* Workouts List */}
                  <div className="p-4 space-y-3">
                    {day.workouts.length > 0 ? (
                      <DndContext
                        sensors={sensors}
                        collisionDetection={closestCenter}
                        onDragEnd={(event) => handleDragEnd(event, day.id)}
                      >
                        <SortableContext
                          items={day.workouts.map(w => w.id)}
                          strategy={verticalListSortingStrategy}
                        >
                          <div className="space-y-3">
                            {day.workouts.map((workout, idx) => (
                              <SortableWorkoutItem
                                key={workout.id}
                                workout={workout}
                                index={idx}
                                onEdit={() => handleEditWorkout(day.id, workout)}
                                onDelete={() => handleDeleteWorkout(day.id, workout.id)}
                              />
                            ))}
                          </div>
                        </SortableContext>
                      </DndContext>
                    ) : (
                      <div className="text-center py-6 text-[#94A3B8] text-[13px]">
                        No workouts added
                      </div>
                    )}

                    <button
                      onClick={() => handleAddWorkout(day.id)}
                      className="w-full px-3 py-2 text-[13px] font-medium text-[#64748B] bg-white border border-dashed border-[#E2E8F0] rounded-lg hover:border-[#2563EB] hover:text-[#2563EB] transition-colors flex items-center justify-center gap-2"
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                      </svg>
                      Add Workout
                    </button>
                  </div>
                </div>
              ))}

              {/* Add New Day Card */}
              <button
                onClick={handleAddDay}
                className="min-h-[200px] bg-white rounded-lg border-2 border-dashed border-[#E2E8F0] hover:border-[#2563EB] transition-colors flex flex-col items-center justify-center gap-3 text-[#64748B] hover:text-[#2563EB]"
              >
                <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                <span className="text-[14px] font-medium">Add New Day</span>
              </button>
            </div>
          </div>
        ) : (
          <div className="text-center py-16 text-[#94A3B8]">
            <p className="text-[14px]">No weeks created yet. Click "Add New Week" to get started.</p>
          </div>
        )}
      </div>

      {/* Add Workout Modal */}
      <AddWorkoutModal
        isOpen={isAddWorkoutModalOpen}
        onClose={() => {
          setIsAddWorkoutModalOpen(false);
          setSelectedDayId(null);
          setEditingWorkout(null);
          setModalMode('add');
        }}
        onAdd={handleWorkoutAdded}
        editingWorkout={editingWorkout}
        mode={modalMode}
      />

      {/* Bulk Edit Target Reps Modal */}
      <BulkEditTargetRepsModal
        isOpen={isBulkEditRepsOpen}
        onClose={() => setIsBulkEditRepsOpen(false)}
        onUpdate={handleBulkUpdateTargetReps}
        weekNumber={currentWeek?.number || 0}
        currentValues={getUniqueTargetReps()}
      />
    </div>
    </>
  );
}
