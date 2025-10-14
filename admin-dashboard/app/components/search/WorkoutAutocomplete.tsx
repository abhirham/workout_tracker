'use client';

import { useState, useEffect, useRef } from 'react';

interface GlobalWorkout {
  id: string;
  name: string;
  type: 'Weight' | 'Timer';
  muscleGroups: string[];
  equipment: string[];
}

interface WorkoutAutocompleteProps {
  onSelect: (workout: GlobalWorkout) => void;
  placeholder?: string;
}

export default function WorkoutAutocomplete({ onSelect, placeholder = 'Search workouts...' }: WorkoutAutocompleteProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [workouts, setWorkouts] = useState<GlobalWorkout[]>([]);
  const [filteredWorkouts, setFilteredWorkouts] = useState<GlobalWorkout[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // Mock data - replace with actual Firebase query
    const mockWorkouts: GlobalWorkout[] = [
      {
        id: '1',
        name: 'Bench Press',
        type: 'Weight',
        muscleGroups: ['Chest', 'Triceps'],
        equipment: ['Barbell', 'Bench'],
      },
      {
        id: '2',
        name: 'Squat',
        type: 'Weight',
        muscleGroups: ['Legs', 'Glutes'],
        equipment: ['Barbell'],
      },
      {
        id: '3',
        name: 'Deadlift',
        type: 'Weight',
        muscleGroups: ['Back', 'Legs'],
        equipment: ['Barbell'],
      },
      {
        id: '4',
        name: 'Overhead Press',
        type: 'Weight',
        muscleGroups: ['Shoulders', 'Triceps'],
        equipment: ['Barbell'],
      },
      {
        id: '5',
        name: 'Pull Ups',
        type: 'Weight',
        muscleGroups: ['Back', 'Biceps'],
        equipment: ['Pull-up Bar'],
      },
      {
        id: '6',
        name: 'Plank',
        type: 'Timer',
        muscleGroups: ['Core'],
        equipment: ['Bodyweight'],
      },
    ];
    setWorkouts(mockWorkouts);
  }, []);

  useEffect(() => {
    if (searchTerm.trim()) {
      const filtered = workouts.filter(w =>
        w.name.toLowerCase().includes(searchTerm.toLowerCase())
      );
      setFilteredWorkouts(filtered);
      setIsOpen(true);
    } else {
      setFilteredWorkouts([]);
      setIsOpen(false);
    }
  }, [searchTerm, workouts]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleSelect = (workout: GlobalWorkout) => {
    onSelect(workout);
    setSearchTerm(workout.name);
    setIsOpen(false);
  };

  return (
    <div className="relative w-full" ref={dropdownRef}>
      <div className="relative">
        <svg
          className="absolute left-3 top-1/2 -translate-y-1/2 w-[18px] h-[18px] text-[#94A3B8]"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          type="text"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          onFocus={() => searchTerm && setIsOpen(true)}
          placeholder={placeholder}
          className="w-full pl-10 pr-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
        />
      </div>

      {isOpen && filteredWorkouts.length > 0 && (
        <div className="absolute z-50 w-full mt-2 bg-white border border-[#E2E8F0] rounded-lg shadow-lg max-h-[300px] overflow-y-auto">
          {filteredWorkouts.map((workout) => (
            <button
              key={workout.id}
              onClick={() => handleSelect(workout)}
              className="w-full px-4 py-3 flex items-center justify-between hover:bg-[#F8FAFC] transition-colors text-left border-b border-[#E2E8F0] last:border-b-0"
            >
              <div className="flex-1">
                <div className="text-[14px] font-semibold text-[#000000] mb-1">
                  {workout.name}
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {workout.muscleGroups.map((group, i) => (
                    <span
                      key={i}
                      className="inline-flex px-2 py-0.5 text-[11px] font-medium text-[#64748B] bg-[#F1F5F9] rounded"
                    >
                      {group}
                    </span>
                  ))}
                </div>
              </div>
              <span className="inline-flex items-center px-2.5 py-1 rounded-full text-[12px] font-semibold bg-[#000000] text-white ml-3">
                {workout.type.toLowerCase()}
              </span>
            </button>
          ))}
        </div>
      )}

      {isOpen && filteredWorkouts.length === 0 && searchTerm && (
        <div className="absolute z-50 w-full mt-2 bg-white border border-[#E2E8F0] rounded-lg shadow-lg p-4 text-center text-[14px] text-[#64748B]">
          No workouts found
        </div>
      )}
    </div>
  );
}
