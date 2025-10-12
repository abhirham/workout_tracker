'use client';

import { useState, useEffect } from 'react';
import { db } from '@/lib/firebase';
import {
  collection,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  getDocs,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

interface GlobalWorkout {
  id: string;
  name: string;
  type: 'weight' | 'timer';
  muscleGroups: string[];
  equipment: string[];
  searchKeywords: string[];
  isActive: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export default function GlobalWorkoutsPage() {
  const [workouts, setWorkouts] = useState<GlobalWorkout[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingWorkout, setEditingWorkout] = useState<GlobalWorkout | null>(null);

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    type: 'weight' as 'weight' | 'timer',
    muscleGroups: '',
    equipment: '',
    searchKeywords: '',
    isActive: true,
  });

  // Load workouts
  useEffect(() => {
    loadWorkouts();
  }, []);

  const loadWorkouts = async () => {
    try {
      const querySnapshot = await getDocs(collection(db, 'global_workouts'));
      const workoutsData = querySnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as GlobalWorkout[];
      setWorkouts(workoutsData.sort((a, b) => a.name.localeCompare(b.name)));
    } catch (error) {
      console.error('Error loading workouts:', error);
      alert('Failed to load workouts');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const workoutData = {
      name: formData.name.trim(),
      type: formData.type,
      muscleGroups: formData.muscleGroups.split(',').map((s) => s.trim()).filter(Boolean),
      equipment: formData.equipment.split(',').map((s) => s.trim()).filter(Boolean),
      searchKeywords: formData.searchKeywords
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean),
      isActive: formData.isActive,
      updatedAt: serverTimestamp(),
    };

    try {
      if (editingWorkout) {
        // Update existing workout
        await updateDoc(doc(db, 'global_workouts', editingWorkout.id), workoutData);
        alert('Workout updated successfully!');
      } else {
        // Create new workout
        const id = formData.name
          .toLowerCase()
          .replace(/\s+/g, '-')
          .replace(/[^a-z0-9-]/g, '');

        await addDoc(collection(db, 'global_workouts'), {
          id,
          ...workoutData,
          createdAt: serverTimestamp(),
        });
        alert('Workout created successfully!');
      }

      setShowModal(false);
      resetForm();
      loadWorkouts();
    } catch (error) {
      console.error('Error saving workout:', error);
      alert('Failed to save workout');
    }
  };

  const handleEdit = (workout: GlobalWorkout) => {
    setEditingWorkout(workout);
    setFormData({
      name: workout.name,
      type: workout.type,
      muscleGroups: workout.muscleGroups.join(', '),
      equipment: workout.equipment.join(', '),
      searchKeywords: workout.searchKeywords.join(', '),
      isActive: workout.isActive,
    });
    setShowModal(true);
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this workout?')) return;

    try {
      await deleteDoc(doc(db, 'global_workouts', id));
      alert('Workout deleted successfully!');
      loadWorkouts();
    } catch (error) {
      console.error('Error deleting workout:', error);
      alert('Failed to delete workout');
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      type: 'weight',
      muscleGroups: '',
      equipment: '',
      searchKeywords: '',
      isActive: true,
    });
    setEditingWorkout(null);
  };

  const closeModal = () => {
    setShowModal(false);
    resetForm();
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-xl text-gray-600">Loading workouts...</div>
      </div>
    );
  }

  return (
    <div className="px-4 py-6">
      <div className="sm:flex sm:items-center">
        <div className="sm:flex-auto">
          <h1 className="text-3xl font-bold text-gray-900">Global Workouts</h1>
          <p className="mt-2 text-sm text-gray-700">
            Manage the library of exercises that can be used in workout plans ({workouts.length} total)
          </p>
        </div>
        <div className="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <button
            onClick={() => setShowModal(true)}
            className="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-primary-600 hover:bg-primary-700"
          >
            Add Workout
          </button>
        </div>
      </div>

      {/* Workouts Table */}
      <div className="mt-8 flex flex-col">
        <div className="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div className="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div className="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table className="min-w-full divide-y divide-gray-300">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Name</th>
                    <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Type</th>
                    <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Muscle Groups</th>
                    <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Equipment</th>
                    <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Status</th>
                    <th className="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span className="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 bg-white">
                  {workouts.map((workout) => (
                    <tr key={workout.id}>
                      <td className="whitespace-nowrap px-3 py-4 text-sm font-medium text-gray-900">
                        {workout.name}
                      </td>
                      <td className="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <span className={`inline-flex rounded-full px-2 text-xs font-semibold leading-5 ${
                          workout.type === 'weight' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'
                        }`}>
                          {workout.type}
                        </span>
                      </td>
                      <td className="px-3 py-4 text-sm text-gray-500">
                        {workout.muscleGroups.join(', ')}
                      </td>
                      <td className="px-3 py-4 text-sm text-gray-500">
                        {workout.equipment.join(', ')}
                      </td>
                      <td className="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                        <span className={`inline-flex rounded-full px-2 text-xs font-semibold leading-5 ${
                          workout.isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                        }`}>
                          {workout.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                      <td className="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <button
                          onClick={() => handleEdit(workout)}
                          className="text-primary-600 hover:text-primary-900 mr-4"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => handleDelete(workout.id)}
                          className="text-red-600 hover:text-red-900"
                        >
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="px-6 py-4 border-b border-gray-200">
              <h3 className="text-lg font-medium text-gray-900">
                {editingWorkout ? 'Edit Workout' : 'Create New Workout'}
              </h3>
            </div>

            <form onSubmit={handleSubmit} className="px-6 py-4 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700">Name</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-primary-500 focus:border-primary-500"
                  placeholder="e.g., Bench Press"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Type</label>
                <select
                  value={formData.type}
                  onChange={(e) => setFormData({ ...formData, type: e.target.value as 'weight' | 'timer' })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-primary-500 focus:border-primary-500"
                >
                  <option value="weight">Weight</option>
                  <option value="timer">Timer</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Muscle Groups (comma-separated)</label>
                <input
                  type="text"
                  required
                  value={formData.muscleGroups}
                  onChange={(e) => setFormData({ ...formData, muscleGroups: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-primary-500 focus:border-primary-500"
                  placeholder="e.g., chest, triceps"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Equipment (comma-separated)</label>
                <input
                  type="text"
                  required
                  value={formData.equipment}
                  onChange={(e) => setFormData({ ...formData, equipment: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-primary-500 focus:border-primary-500"
                  placeholder="e.g., barbell, bench"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Search Keywords (comma-separated)</label>
                <input
                  type="text"
                  required
                  value={formData.searchKeywords}
                  onChange={(e) => setFormData({ ...formData, searchKeywords: e.target.value })}
                  className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-primary-500 focus:border-primary-500"
                  placeholder="e.g., bench, press, chest"
                />
              </div>

              <div className="flex items-center">
                <input
                  type="checkbox"
                  checked={formData.isActive}
                  onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                  className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
                />
                <label className="ml-2 block text-sm text-gray-900">Active</label>
              </div>

              <div className="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                <button
                  type="button"
                  onClick={closeModal}
                  className="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-primary-600 hover:bg-primary-700"
                >
                  {editingWorkout ? 'Update' : 'Create'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
