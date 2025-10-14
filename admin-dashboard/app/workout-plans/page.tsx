'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
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

interface WorkoutPlan {
  id: string;
  name: string;
  description: string;
  totalWeeks: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export default function WorkoutPlansPage() {
  const [plans, setPlans] = useState<WorkoutPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    fetchPlans();
  }, []);

  const fetchPlans = async () => {
    try {
      setLoading(true);
      const q = query(collection(db, 'workout_plans'), orderBy('createdAt', 'desc'));
      const snapshot = await getDocs(q);

      const plansData = await Promise.all(
        snapshot.docs.map(async (planDoc) => {
          const data = planDoc.data();

          // Count weeks by fetching weeks subcollection
          const weeksSnapshot = await getDocs(collection(db, 'workout_plans', planDoc.id, 'weeks'));
          const totalWeeks = weeksSnapshot.size;

          return {
            id: planDoc.id,
            name: data.name || '',
            description: data.description || '',
            totalWeeks: totalWeeks,
            isActive: data.isActive ?? true,
            createdAt: data.createdAt?.toDate() || new Date(),
            updatedAt: data.updatedAt?.toDate() || new Date(),
          };
        })
      );

      setPlans(plansData);
    } catch (error) {
      console.error('Error fetching plans:', error);
      alert('Failed to fetch workout plans');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleActive = async (plan: WorkoutPlan) => {
    try {
      await updateDoc(doc(db, 'workout_plans', plan.id), {
        isActive: !plan.isActive,
        updatedAt: Timestamp.now(),
      });
      await fetchPlans();
    } catch (error) {
      console.error('Error toggling active status:', error);
      alert('Failed to update plan status');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this plan? This will also delete all weeks, days, and workouts.')) return;
    try {
      // Note: In production, you'd want to use a Cloud Function to delete subcollections
      // For now, just delete the plan document (subcollections will remain orphaned)
      await deleteDoc(doc(db, 'workout_plans', id));
      await fetchPlans();
    } catch (error) {
      console.error('Error deleting plan:', error);
      alert('Failed to delete workout plan');
    }
  };

  const filteredPlans = plans.filter(p =>
    p.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center space-y-4">
          <div className="w-16 h-16 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
          <p className="text-gray-500 font-medium">Loading workout plans...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-[32px] font-bold text-[#000000] leading-[1.2]">Workout Plans</h1>
          <p className="text-[14px] text-[#64748B] mt-1">Manage all your workout programs</p>
        </div>
        <Link
          href="/workout-plans/new"
          className="px-4 py-2.5 bg-[#0F172A] text-white text-[14px] font-medium rounded-lg hover:bg-[#1E293B] transition-colors flex items-center space-x-2"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          <span>Create New Plan</span>
        </Link>
      </div>

      {/* Search */}
      <div className="relative max-w-md">
        <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-[18px] h-[18px] text-[#94A3B8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          type="text"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          placeholder="Search plans..."
          className="w-full pl-10 pr-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-[#F8FAFC] focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
        />
      </div>

      {/* Plans Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredPlans.map((plan) => (
          <div
            key={plan.id}
            className="bg-white rounded-lg border border-[#E2E8F0] overflow-hidden hover:shadow-md transition-shadow"
          >
            {/* Card Content */}
            <div className="p-6">
              <div className="flex items-start justify-between mb-3">
                <div className="flex-1">
                  <h3 className="text-[18px] font-semibold text-[#000000] mb-2">
                    {plan.name}
                  </h3>
                  <p className="text-[14px] text-[#64748B] line-clamp-2">
                    {plan.description}
                  </p>
                </div>
                <button
                  onClick={() => handleToggleActive(plan)}
                  className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:ring-offset-2 ml-4 ${
                    plan.isActive ? 'bg-[#000000]' : 'bg-[#E2E8F0]'
                  }`}
                >
                  <span
                    className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                      plan.isActive ? 'translate-x-5' : 'translate-x-0'
                    }`}
                  />
                </button>
              </div>

              {/* Stats */}
              <div className="flex items-center gap-3 mt-4">
                <span className="inline-flex items-center px-2.5 py-1 rounded-md text-[12px] font-medium bg-[#F1F5F9] text-[#000000]">
                  {plan.totalWeeks} Weeks
                </span>
                <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-[12px] font-semibold ${
                  plan.isActive
                    ? 'bg-[#000000] text-white'
                    : 'bg-[#F1F5F9] text-[#64748B]'
                }`}>
                  {plan.isActive ? 'Active' : 'Inactive'}
                </span>
              </div>
            </div>

            {/* Actions */}
            <div className="px-6 py-4 bg-[#F8FAFC] border-t border-[#E2E8F0] flex items-center gap-2">
              <Link
                href={`/workout-plans/${plan.id}`}
                className="flex-1 inline-flex items-center justify-center px-4 py-2 text-[14px] font-medium text-[#000000] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors"
              >
                <svg className="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
                Edit
              </Link>
              <button
                className="px-4 py-2 text-[14px] font-medium text-[#64748B] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] hover:text-[#000000] transition-colors"
                title="Duplicate"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </button>
              <button
                onClick={() => handleDelete(plan.id)}
                className="px-4 py-2 text-[14px] font-medium text-[#64748B] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#FEE2E2] hover:text-[#DC2626] hover:border-[#FCA5A5] transition-colors"
                title="Delete"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Empty State */}
      {filteredPlans.length === 0 && (
        <div className="text-center py-16 bg-white rounded-lg border-2 border-dashed border-[#E2E8F0]">
          <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-[#F1F5F9] flex items-center justify-center">
            <svg className="w-8 h-8 text-[#64748B]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <h3 className="text-[18px] font-semibold text-[#000000] mb-2">No Workout Plans Found</h3>
          <p className="text-[14px] text-[#64748B] mb-6">
            {searchTerm ? 'Try adjusting your search' : 'Create your first workout plan to get started'}
          </p>
        </div>
      )}
    </div>
  );
}
