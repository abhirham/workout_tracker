'use client';

import { useState, useEffect } from 'react';
import { db } from '@/lib/firebase';
import {
  collection,
  getDocs,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  query,
  orderBy,
  Timestamp,
} from 'firebase/firestore';

type WorkoutType = 'Weight' | 'Timer';

interface GlobalWorkout {
  id: string;
  name: string;
  type: WorkoutType;
  muscleGroups: string[];
  equipment: string[];
  searchKeywords: string[];
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export default function GlobalWorkoutsPage() {
  const [workouts, setWorkouts] = useState<GlobalWorkout[]>([]);
  const [filteredWorkouts, setFilteredWorkouts] = useState<GlobalWorkout[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState('All Types');
  const [muscleGroupFilter, setMuscleGroupFilter] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingWorkout, setEditingWorkout] = useState<GlobalWorkout | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    type: 'Weight' as WorkoutType,
    muscleGroups: '',
    equipment: '',
    searchKeywords: '',
    isActive: true,
  });

  const muscleGroupOptions = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Biceps', 'Triceps', 'Core', 'Glutes', 'Cardio'];

  useEffect(() => {
    fetchWorkouts();
  }, []);

  useEffect(() => {
    filterWorkouts();
  }, [searchTerm, typeFilter, muscleGroupFilter, workouts]);

  const fetchWorkouts = async () => {
    try {
      setLoading(true);
      const q = query(collection(db, 'global_workouts'), orderBy('name'));
      const snapshot = await getDocs(q);
      const workoutsData = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.name,
          type: data.type || 'Weight',
          muscleGroups: data.muscleGroups || [],
          equipment: data.equipment || [],
          searchKeywords: data.searchKeywords || [],
          isActive: data.isActive ?? true,
          createdAt: data.createdAt?.toDate() || new Date(),
          updatedAt: data.updatedAt?.toDate() || new Date(),
        };
      });
      setWorkouts(workoutsData);
      setFilteredWorkouts(workoutsData);
    } catch (error) {
      console.error('Error fetching workouts:', error);
      alert('Failed to fetch workouts');
    } finally {
      setLoading(false);
    }
  };

  const filterWorkouts = () => {
    let filtered = workouts;

    if (searchTerm) {
      filtered = filtered.filter(w =>
        w.name.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    if (typeFilter !== 'All Types') {
      filtered = filtered.filter(w => w.type === typeFilter);
    }

    if (muscleGroupFilter) {
      filtered = filtered.filter(w =>
        w.muscleGroups.some(mg => mg.toLowerCase() === muscleGroupFilter.toLowerCase())
      );
    }

    setFilteredWorkouts(filtered);
  };

  const handleOpenModal = (workout?: GlobalWorkout) => {
    if (workout) {
      setEditingWorkout(workout);
      setFormData({
        name: workout.name,
        type: workout.type,
        muscleGroups: workout.muscleGroups.join(', '),
        equipment: workout.equipment.join(', '),
        searchKeywords: workout.searchKeywords.join(', '),
        isActive: workout.isActive,
      });
    } else {
      setEditingWorkout(null);
      setFormData({
        name: '',
        type: 'Weight',
        muscleGroups: '',
        equipment: '',
        searchKeywords: '',
        isActive: true,
      });
    }
    setShowModal(true);
  };

  const handleCloseModal = () => {
    setShowModal(false);
    setEditingWorkout(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const workoutData = {
      name: formData.name.trim(),
      type: formData.type,
      muscleGroups: formData.muscleGroups
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
      equipment: formData.equipment
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
      searchKeywords: formData.searchKeywords
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean),
      isActive: formData.isActive,
      updatedAt: Timestamp.now(),
    };

    try {
      if (editingWorkout) {
        await updateDoc(doc(db, 'global_workouts', editingWorkout.id), workoutData);
      } else {
        await addDoc(collection(db, 'global_workouts'), {
          ...workoutData,
          createdAt: Timestamp.now(),
        });
      }
      await fetchWorkouts();
      handleCloseModal();
    } catch (error) {
      console.error('Error saving workout:', error);
      alert('Failed to save workout');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this workout?')) return;

    try {
      await deleteDoc(doc(db, 'global_workouts', id));
      await fetchWorkouts();
    } catch (error) {
      console.error('Error deleting workout:', error);
      alert('Failed to delete workout');
    }
  };

  const handleToggleActive = async (workout: GlobalWorkout) => {
    try {
      await updateDoc(doc(db, 'global_workouts', workout.id), {
        isActive: !workout.isActive,
        updatedAt: Timestamp.now(),
      });
      await fetchWorkouts();
    } catch (error) {
      console.error('Error toggling active status:', error);
      alert('Failed to update workout status');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center space-y-4">
          <div className="w-16 h-16 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
          <p className="text-gray-500 font-medium">Loading workouts...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-[32px] font-bold text-[#000000] leading-[1.2]">Global Workouts Library</h1>
          <p className="text-[14px] text-[#64748B] mt-1">Manage your master exercise database</p>
        </div>
        <button
          onClick={() => handleOpenModal()}
          className="px-4 py-2.5 bg-[#0F172A] text-white text-[14px] font-medium rounded-lg hover:bg-[#1E293B] transition-colors flex items-center space-x-2"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          <span>Add New Workout</span>
        </button>
      </div>

      {/* Search & Filter Section */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
        <h3 className="text-[14px] font-semibold text-[#000000] mb-4">Search & Filter</h3>
        <div className="flex items-center gap-4">
          {/* Search */}
          <div className="relative flex-1">
            <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-[18px] h-[18px] text-[#94A3B8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search workouts..."
              className="w-full pl-10 pr-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-[#F8FAFC] focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
            />
          </div>

          {/* Type Filter Dropdown */}
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            className="px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent min-w-[150px]"
          >
            <option>All Types</option>
            <option>Weight</option>
            <option>Timer</option>
          </select>

          {/* Muscle Group Filter Pills */}
          <div className="flex items-center gap-2">
            <span className="text-[14px] font-medium text-[#000000] whitespace-nowrap">Filter by Muscle Group</span>
            <div className="flex gap-2">
              {muscleGroupOptions.slice(0, 3).map((group) => (
                <button
                  key={group}
                  onClick={() => setMuscleGroupFilter(muscleGroupFilter === group ? '' : group)}
                  className={`px-3 py-1.5 text-[13px] font-medium rounded-md transition-colors ${
                    muscleGroupFilter === group
                      ? 'bg-[#2563EB] text-white'
                      : 'bg-[#F1F5F9] text-[#334155] hover:bg-[#E2E8F0]'
                  }`}
                >
                  {group}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="bg-[#F8FAFC] border-b border-[#E2E8F0]">
              <tr>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Workout Name
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Muscle Groups
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Equipment
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-right text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-[#E2E8F0]">
              {filteredWorkouts.map((workout) => (
                <tr key={workout.id} className="hover:bg-[#F8FAFC] transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-[14px] font-medium text-[#000000]">{workout.name}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="inline-flex px-2.5 py-1 rounded-full text-[12px] font-semibold bg-[#000000] text-white">
                      {workout.type}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex flex-wrap gap-1.5">
                      {workout.muscleGroups.map((group, i) => (
                        <span
                          key={i}
                          className="inline-flex px-2 py-0.5 text-[12px] font-medium text-[#334155] bg-[#F1F5F9] rounded"
                        >
                          {group}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex flex-wrap gap-1.5">
                      {workout.equipment.map((eq, i) => (
                        <span
                          key={i}
                          className="inline-flex px-2 py-0.5 text-[12px] font-medium text-[#334155] bg-[#F1F5F9] rounded"
                        >
                          {eq}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="inline-flex px-2.5 py-1 rounded-full text-[12px] font-semibold bg-[#000000] text-white">
                      Active
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right">
                    <div className="flex items-center justify-end gap-3">
                      <button
                        onClick={() => handleOpenModal(workout)}
                        className="text-[#64748B] hover:text-[#2563EB] transition-colors"
                      >
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </button>
                      <button
                        onClick={() => handleDelete(workout.id)}
                        className="text-[#64748B] hover:text-[#DC2626] transition-colors"
                      >
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4">
            <div
              className="fixed inset-0 bg-black/30 backdrop-blur-sm transition-opacity"
              onClick={handleCloseModal}
            ></div>
            <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-2xl p-8">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-2xl font-bold text-gray-900">
                  {editingWorkout ? 'Edit Workout' : 'Add New Workout'}
                </h3>
                <button
                  onClick={handleCloseModal}
                  className="w-10 h-10 rounded-full hover:bg-gray-100 flex items-center justify-center transition-colors"
                >
                  <svg className="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <form onSubmit={handleSubmit} className="space-y-6">
                <div>
                  <label htmlFor="name" className="block text-sm font-semibold text-gray-700 mb-2">
                    Exercise Name
                  </label>
                  <input
                    type="text"
                    id="name"
                    required
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    placeholder="e.g., Bench Press"
                  />
                </div>

                <div>
                  <label htmlFor="type" className="block text-sm font-semibold text-gray-700 mb-2">
                    Workout Type
                  </label>
                  <select
                    id="type"
                    value={formData.type}
                    onChange={(e) => setFormData({ ...formData, type: e.target.value as WorkoutType })}
                    className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  >
                    <option value="Weight">Weight</option>
                    <option value="Timer">Timer</option>
                  </select>
                </div>

                <div>
                  <label htmlFor="muscleGroups" className="block text-sm font-semibold text-gray-700 mb-2">
                    Muscle Groups (comma-separated)
                  </label>
                  <input
                    type="text"
                    id="muscleGroups"
                    value={formData.muscleGroups}
                    onChange={(e) => setFormData({ ...formData, muscleGroups: e.target.value })}
                    placeholder="Chest, Triceps, Shoulders"
                    className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>

                <div>
                  <label htmlFor="equipment" className="block text-sm font-semibold text-gray-700 mb-2">
                    Equipment (comma-separated)
                  </label>
                  <input
                    type="text"
                    id="equipment"
                    value={formData.equipment}
                    onChange={(e) => setFormData({ ...formData, equipment: e.target.value })}
                    placeholder="Barbell, Bench"
                    className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>

                <div>
                  <label htmlFor="searchKeywords" className="block text-sm font-semibold text-gray-700 mb-2">
                    Search Keywords (comma-separated)
                  </label>
                  <input
                    type="text"
                    id="searchKeywords"
                    value={formData.searchKeywords}
                    onChange={(e) => setFormData({ ...formData, searchKeywords: e.target.value })}
                    placeholder="bench, press, chest"
                    className="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>

                <div className="flex items-center space-x-3">
                  <input
                    type="checkbox"
                    id="isActive"
                    checked={formData.isActive}
                    onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                    className="w-4 h-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <label htmlFor="isActive" className="text-sm font-semibold text-gray-900">
                    Mark as Active
                  </label>
                </div>

                <div className="flex items-center space-x-4 pt-4">
                  <button
                    type="submit"
                    className="flex-1 px-4 py-2.5 bg-black text-white text-sm font-medium rounded-lg hover:bg-gray-800 transition-colors"
                  >
                    {editingWorkout ? 'Update Workout' : 'Create Workout'}
                  </button>
                  <button
                    type="button"
                    onClick={handleCloseModal}
                    className="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-200 transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
