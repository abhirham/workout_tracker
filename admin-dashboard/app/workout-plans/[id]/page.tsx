'use client';

import { useState, useEffect } from 'react';
import { useRouter, useParams } from 'next/navigation';
import AddWorkoutModal from '@/app/components/modals/AddWorkoutModal';

interface Workout {
  id: string;
  name: string;
  type: 'Weight' | 'Timer';
  config: {
    baseWeight?: number;
    targetReps?: number;
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

export default function EditPlanPage() {
  const router = useRouter();
  const params = useParams();
  const planId = params.id as string;

  const [plan, setPlan] = useState<WorkoutPlan>({
    id: planId === 'new' ? '' : planId,
    name: '',
    description: '',
    weeks: [],
  });

  const [activeWeekIndex, setActiveWeekIndex] = useState(0);
  const [isAddWorkoutModalOpen, setIsAddWorkoutModalOpen] = useState(false);
  const [selectedDayId, setSelectedDayId] = useState<string | null>(null);

  useEffect(() => {
    if (planId !== 'new') {
      // Fetch existing plan - mock data for now
      setPlan({
        id: planId,
        name: 'Beginner Strength Training',
        description: 'A comprehensive 8-week program designed for beginners to build foundational strength',
        weeks: [
          {
            id: 'week-1',
            number: 1,
            days: [],
          },
          {
            id: 'week-2',
            number: 2,
            days: [
              {
                id: 'day-1',
                name: 'Day 1',
                workouts: [
                  {
                    id: 'workout-1',
                    name: 'Overhead Press',
                    type: 'Weight',
                    config: {
                      numSets: 4,
                      targetReps: 12,
                      baseWeight: 10,
                      restTimer: 45,
                    },
                  },
                  {
                    id: 'workout-2',
                    name: 'Pull Ups',
                    type: 'Weight',
                    config: {
                      numSets: 4,
                      targetReps: 12,
                      baseWeight: 10,
                      restTimer: 45,
                    },
                  },
                ],
              },
              {
                id: 'day-2',
                name: 'Day 1 (Copy)',
                workouts: [],
              },
            ],
          },
        ],
      });
      setActiveWeekIndex(1); // Show Week 2 by default for demo
    }
  }, [planId]);

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
        name: `${day.name} (Copy)`,
      })),
    };
    setPlan({ ...plan, weeks: [...plan.weeks, copiedWeek] });
  };

  const handleDeleteWeek = () => {
    if (plan.weeks.length <= 1) {
      alert('Cannot delete the last week');
      return;
    }
    if (!confirm('Are you sure you want to delete this week?')) return;

    const newWeeks = plan.weeks.filter((_, idx) => idx !== activeWeekIndex);
    setPlan({ ...plan, weeks: newWeeks });
    setActiveWeekIndex(Math.max(0, activeWeekIndex - 1));
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

  const handleCopyDay = (dayId: string) => {
    const currentWeek = plan.weeks[activeWeekIndex];
    if (!currentWeek) return;

    const dayToCopy = currentWeek.days.find(d => d.id === dayId);
    if (!dayToCopy) return;

    const copiedDay: Day = {
      ...dayToCopy,
      id: `day-${Date.now()}`,
      name: `${dayToCopy.name} (Copy)`,
    };

    const updatedWeeks = [...plan.weeks];
    updatedWeeks[activeWeekIndex] = {
      ...currentWeek,
      days: [...currentWeek.days, copiedDay],
    };
    setPlan({ ...plan, weeks: updatedWeeks });
  };

  const handleDeleteDay = (dayId: string) => {
    if (!confirm('Are you sure you want to delete this day?')) return;

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
    updatedDays[dayIndex] = {
      ...updatedDays[dayIndex],
      workouts: [...updatedDays[dayIndex].workouts, workout],
    };

    updatedWeeks[activeWeekIndex] = {
      ...currentWeek,
      days: updatedDays,
    };

    setPlan({ ...plan, weeks: updatedWeeks });
  };

  const handleDeleteWorkout = (dayId: string, workoutId: string) => {
    if (!confirm('Are you sure you want to delete this workout?')) return;

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

  const handleSave = () => {
    // Save to Firebase
    console.log('Saving plan:', plan);
    alert('Plan saved successfully!');
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

  const currentWeek = plan.weeks[activeWeekIndex];

  return (
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

      {/* Plan Overview */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] p-8">
        <div className="flex items-start justify-between mb-6">
          <div>
            <h2 className="text-[20px] font-bold text-[#000000]">Plan Overview</h2>
            <p className="text-[14px] text-[#64748B] mt-1">Configure your workout plan details</p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={handleExportJSON}
              className="px-4 py-2 text-[14px] font-medium text-[#000000] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors"
            >
              Export as JSON
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

            {/* Days Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {currentWeek.days.map((day) => (
                <div key={day.id} className="bg-white rounded-lg border border-[#E2E8F0] overflow-hidden">
                  {/* Day Header */}
                  <div className="px-4 py-3 bg-[#F8FAFC] border-b border-[#E2E8F0] flex items-center justify-between">
                    <h4 className="text-[14px] font-semibold text-[#000000]">{day.name}</h4>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => handleCopyDay(day.id)}
                        className="p-1 text-[#64748B] hover:text-[#000000] transition-colors"
                        title="Copy Day"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                        </svg>
                      </button>
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
                  </div>

                  {/* Workouts List */}
                  <div className="p-4 space-y-3">
                    {day.workouts.length > 0 ? (
                      day.workouts.map((workout, idx) => (
                        <div key={workout.id} className="flex items-start gap-2">
                          <div className="flex-shrink-0 mt-1">
                            <svg className="w-4 h-4 text-[#94A3B8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <circle cx="9" cy="5" r="1" fill="currentColor" />
                              <circle cx="9" cy="12" r="1" fill="currentColor" />
                              <circle cx="9" cy="19" r="1" fill="currentColor" />
                              <circle cx="15" cy="5" r="1" fill="currentColor" />
                              <circle cx="15" cy="12" r="1" fill="currentColor" />
                              <circle cx="15" cy="19" r="1" fill="currentColor" />
                            </svg>
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="text-[13px] font-medium text-[#000000]">
                              {idx + 1}. {workout.name}
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
                          <button
                            onClick={() => handleDeleteWorkout(day.id, workout.id)}
                            className="flex-shrink-0 p-1 text-[#64748B] hover:text-[#DC2626] transition-colors"
                          >
                            <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                            </svg>
                          </button>
                        </div>
                      ))
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
        }}
        onAdd={handleWorkoutAdded}
      />
    </div>
  );
}
