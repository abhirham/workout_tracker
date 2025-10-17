'use client';

import { useState, useEffect } from 'react';
import { db } from '@/lib/firebase';
import {
  collection,
  getDocs,
  query,
  orderBy,
} from 'firebase/firestore';
import { useToast } from '@/app/context/ToastContext';

interface User {
  id: string;
  displayName: string;
  email: string;
  currentPlanId: string;
  currentPlanName: string;
  currentWeek: number;
  currentDay: number;
  completionRate: number;
  lastActive: Date;
}

export default function UsersPage() {
  const toast = useToast();
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [planFilter, setPlanFilter] = useState('All Plans');
  const [statusFilter, setStatusFilter] = useState('All Users');

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      // Mock data for now - replace with actual Firestore query
      const mockUsers: User[] = [
        {
          id: '1',
          displayName: 'Sarah Johnson',
          email: 'sarah.j@email.com',
          currentPlanId: 'plan1',
          currentPlanName: 'Beginner Strength Training',
          currentWeek: 3,
          currentDay: 2,
          completionRate: 87,
          lastActive: new Date(Date.now() - 86400000), // Yesterday
        },
        {
          id: '2',
          displayName: 'Mike Chen',
          email: 'mike.chen@email.com',
          currentPlanId: 'plan2',
          currentPlanName: 'Advanced Powerlifting',
          currentWeek: 8,
          currentDay: 5,
          completionRate: 95,
          lastActive: new Date(Date.now() - 86400000),
        },
        {
          id: '3',
          displayName: 'Emily Rodriguez',
          email: 'emily.r@email.com',
          currentPlanId: 'plan3',
          currentPlanName: 'HIIT Cardio Blast',
          currentWeek: 2,
          currentDay: 4,
          completionRate: 72,
          lastActive: new Date(Date.now() - 172800000), // 2 days ago
        },
        {
          id: '4',
          displayName: 'James Wilson',
          email: 'j.wilson@email.com',
          currentPlanId: 'plan1',
          currentPlanName: 'Beginner Strength Training',
          currentWeek: 1,
          currentDay: 3,
          completionRate: 100,
          lastActive: new Date(Date.now() - 86400000),
        },
        {
          id: '5',
          displayName: 'Lisa Anderson',
          email: 'lisa.a@email.com',
          currentPlanId: 'plan4',
          currentPlanName: 'Bodyweight Basics',
          currentWeek: 4,
          currentDay: 7,
          completionRate: 68,
          lastActive: new Date(Date.now() - 345600000), // 4 days ago
        },
        {
          id: '6',
          displayName: 'David Kim',
          email: 'david.kim@email.com',
          currentPlanId: 'plan2',
          currentPlanName: 'Advanced Powerlifting',
          currentWeek: 5,
          currentDay: 1,
          completionRate: 91,
          lastActive: new Date(Date.now() - 86400000),
        },
        {
          id: '7',
          displayName: 'Jessica Martinez',
          email: 'jess.m@email.com',
          currentPlanId: 'plan3',
          currentPlanName: 'HIIT Cardio Blast',
          currentWeek: 4,
          currentDay: 6,
          completionRate: 83,
          lastActive: new Date(Date.now() - 172800000),
        },
        {
          id: '8',
          displayName: 'Robert Taylor',
          email: 'rob.taylor@email.com',
          currentPlanId: 'plan1',
          currentPlanName: 'Beginner Strength Training',
          currentWeek: 6,
          currentDay: 2,
          completionRate: 79,
          lastActive: new Date(Date.now() - 86400000),
        },
      ];
      setUsers(mockUsers);
    } catch (error) {
      console.error('Error fetching users:', error);
      toast.error('Failed to fetch users');
    } finally {
      setLoading(false);
    }
  };

  const filteredUsers = users.filter(u =>
    u.displayName.toLowerCase().includes(searchTerm.toLowerCase()) ||
    u.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getLastActiveText = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days === 0) return 'Today';
    if (days === 1) return 'Yesterday';
    return `${days} days ago`;
  };

  const getInitials = (name: string) => {
    return name.split(' ').map(n => n[0]).join('').toUpperCase();
  };

  const getCompletionColor = (rate: number) => {
    if (rate >= 80) return '#10B981'; // Green
    if (rate >= 60) return '#F59E0B'; // Yellow/Orange
    return '#EF4444'; // Red
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center space-y-4">
          <div className="w-16 h-16 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
          <p className="text-gray-500 font-medium">Loading users...</p>
        </div>
      </div>
    );
  }

  const totalUsers = users.length;
  const activeThisWeek = users.filter(u => {
    const daysSinceActive = Math.floor((Date.now() - u.lastActive.getTime()) / (1000 * 60 * 60 * 24));
    return daysSinceActive <= 7;
  }).length;
  const avgCompletion = Math.round(users.reduce((sum, u) => sum + u.completionRate, 0) / users.length);
  const highPerformers = users.filter(u => u.completionRate >= 80).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-[32px] font-bold text-[#000000] leading-[1.2]">User Management</h1>
        <p className="text-[14px] text-[#64748B] mt-1">View and manage all users and their progress</p>
      </div>

      {/* Search & Filters */}
      <div className="flex items-center gap-4">
        <div className="relative flex-1">
          <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-[18px] h-[18px] text-[#94A3B8]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by name or email..."
            className="w-full pl-10 pr-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-[#F8FAFC] focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
          />
        </div>

        <select
          value={planFilter}
          onChange={(e) => setPlanFilter(e.target.value)}
          className="px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent min-w-[200px]"
        >
          <option>All Plans</option>
          <option>Beginner Strength Training</option>
          <option>Advanced Powerlifting</option>
          <option>HIIT Cardio Blast</option>
        </select>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent min-w-[150px]"
        >
          <option>All Users</option>
          <option>Active</option>
          <option>Inactive</option>
        </select>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
          <div className="text-[12px] text-[#64748B] mb-2 font-medium">Total Users</div>
          <div className="text-[32px] font-bold text-[#000000]">{totalUsers}</div>
        </div>
        <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
          <div className="text-[12px] text-[#64748B] mb-2 font-medium">Active This Week</div>
          <div className="text-[32px] font-bold text-[#000000]">{activeThisWeek}</div>
        </div>
        <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
          <div className="text-[12px] text-[#64748B] mb-2 font-medium">Avg Completion</div>
          <div className="text-[32px] font-bold text-[#000000]">{avgCompletion}%</div>
        </div>
        <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
          <div className="text-[12px] text-[#64748B] mb-2 font-medium">High Performers (80%+)</div>
          <div className="text-[32px] font-bold text-[#000000]">{highPerformers}</div>
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="bg-[#F8FAFC] border-b border-[#E2E8F0]">
              <tr>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  User
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Current Plan
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Progress
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Completion Rate
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Last Active
                </th>
                <th className="px-6 py-3 text-right text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-[#E2E8F0]">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-[#F8FAFC] transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="w-10 h-10 rounded-full bg-[#DBEAFE] flex items-center justify-center text-[#2563EB] text-[14px] font-semibold mr-3">
                        {getInitials(user.displayName)}
                      </div>
                      <div>
                        <div className="text-[14px] font-medium text-[#000000]">{user.displayName}</div>
                        <div className="text-[12px] text-[#64748B]">{user.email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-[14px] text-[#000000]">{user.currentPlanName}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-[14px] text-[#000000]">Week {user.currentWeek}, Day {user.currentDay}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-3">
                      <div className="w-32 bg-[#E2E8F0] rounded-full h-2">
                        <div
                          className="h-2 rounded-full transition-all"
                          style={{
                            width: `${user.completionRate}%`,
                            backgroundColor: getCompletionColor(user.completionRate)
                          }}
                        ></div>
                      </div>
                      <span
                        className="text-[14px] font-semibold min-w-[45px]"
                        style={{ color: getCompletionColor(user.completionRate) }}
                      >
                        {user.completionRate}%
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-[14px] text-[#64748B]">{getLastActiveText(user.lastActive)}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right">
                    <button className="inline-flex items-center text-[14px] text-[#000000] hover:text-[#2563EB] transition-colors">
                      <svg className="w-5 h-5 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                      View Details
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
