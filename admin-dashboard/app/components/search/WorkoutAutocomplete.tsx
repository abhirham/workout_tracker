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
  workouts: GlobalWorkout[];
  onSelect: (workout: GlobalWorkout) => void;
  onCreateNew?: (searchTerm: string) => void;
  placeholder?: string;
}

export default function WorkoutAutocomplete({ workouts, onSelect, onCreateNew, placeholder = 'Search workouts...' }: WorkoutAutocompleteProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [filteredWorkouts, setFilteredWorkouts] = useState<GlobalWorkout[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

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

      {isOpen && searchTerm && (
        <div className="absolute z-50 w-full mt-2 bg-white border border-[#E2E8F0] rounded-lg shadow-lg max-h-[300px] overflow-y-auto">
          {/* Always show "Create new workout" as first option when onCreateNew is provided */}
          {onCreateNew && (
            <button
              onClick={() => {
                onCreateNew(searchTerm);
                setIsOpen(false);
              }}
              className="w-full px-4 py-3 flex items-center gap-2 hover:bg-[#F8FAFC] transition-colors text-left border-b border-[#E2E8F0]"
            >
              <svg className="w-5 h-5 text-[#2563EB]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
              </svg>
              <div>
                <div className="text-[14px] font-semibold text-[#2563EB]">
                  Create new workout
                </div>
                <div className="text-[13px] text-[#64748B] mt-0.5">
                  "{searchTerm}"
                </div>
              </div>
            </button>
          )}

          {/* Show matching workouts */}
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
    </div>
  );
}
