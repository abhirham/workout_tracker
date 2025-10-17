'use client';

import { useState, useEffect } from 'react';
import { db, auth } from '@/lib/firebase';
import {
  collection,
  getDocs,
  doc,
  setDoc,
  deleteDoc,
  query,
  orderBy,
  serverTimestamp,
  onSnapshot,
} from 'firebase/firestore';
import { useToast } from '@/app/context/ToastContext';
import { useAuth } from '../context/AuthContext';

interface AdminUser {
  email: string;
  isAdmin: boolean;
  createdAt: any;
  lastLoginAt?: any;
  displayName?: string;
  photoURL?: string;
}

export default function UsersPage() {
  const toast = useToast();
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);
  const [newAdminEmail, setNewAdminEmail] = useState('');
  const [isAddingAdmin, setIsAddingAdmin] = useState(false);

  useEffect(() => {
    // Real-time listener for users collection
    const q = query(collection(db, 'users'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const usersData = snapshot.docs.map((doc) => ({
          email: doc.id,
          ...doc.data(),
        })) as AdminUser[];
        setUsers(usersData);
        setLoading(false);
      },
      (error) => {
        console.error('Error fetching users:', error);
        toast.error('Failed to fetch admin users');
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [toast]);

  const handleAddAdmin = async () => {
    if (!newAdminEmail.trim()) {
      toast.error('Please enter an email address');
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(newAdminEmail.trim())) {
      toast.error('Please enter a valid email address');
      return;
    }

    // Check if user already exists
    const existingUser = users.find(
      (u) => u.email.toLowerCase() === newAdminEmail.trim().toLowerCase()
    );
    if (existingUser) {
      toast.warning('This email already has admin access');
      return;
    }

    setIsAddingAdmin(true);
    try {
      const userDocRef = doc(db, 'users', newAdminEmail.trim());
      await setDoc(userDocRef, {
        email: newAdminEmail.trim(),
        isAdmin: true,
        createdAt: serverTimestamp(),
      });

      toast.success(`Admin access granted to ${newAdminEmail.trim()}`);
      setNewAdminEmail('');
      setShowAddModal(false);
    } catch (error) {
      console.error('Error adding admin:', error);
      toast.error('Failed to add admin user');
    } finally {
      setIsAddingAdmin(false);
    }
  };

  const handleRemoveAdmin = async (email: string) => {
    // Prevent self-deletion
    if (email === currentUser?.email) {
      toast.error('You cannot remove yourself from admin access');
      return;
    }

    if (!confirm(`Are you sure you want to remove admin access for ${email}?`)) {
      return;
    }

    try {
      const userDocRef = doc(db, 'users', email);
      await deleteDoc(userDocRef);
      toast.success(`Admin access removed for ${email}`);
    } catch (error) {
      console.error('Error removing admin:', error);
      toast.error('Failed to remove admin user');
    }
  };

  const filteredUsers = users.filter((u) =>
    u.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const formatDate = (timestamp: any) => {
    if (!timestamp) return 'Never';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };

  const getInitials = (email: string, displayName?: string) => {
    if (displayName) {
      return displayName
        .split(' ')
        .map((n) => n[0])
        .join('')
        .toUpperCase()
        .substring(0, 2);
    }
    return email.substring(0, 2).toUpperCase();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="flex flex-col items-center space-y-4">
          <div className="w-16 h-16 border-4 border-[#2563EB] border-t-transparent rounded-full animate-spin"></div>
          <p className="text-[14px] text-[#64748B] font-medium">Loading admin users...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[32px] font-bold text-[#000000] leading-[1.2]">Admin Management</h1>
          <p className="text-[14px] text-[#64748B] mt-1">
            Manage admin users who can access this dashboard
          </p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="px-4 py-2.5 bg-[#2563EB] text-white text-[14px] font-medium rounded-lg hover:bg-[#1D4ED8] transition-colors flex items-center gap-2"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Add Admin
        </button>
      </div>

      {/* Search */}
      <div className="relative max-w-md">
        <svg
          className="absolute left-3 top-1/2 -translate-y-1/2 w-[18px] h-[18px] text-[#94A3B8]"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          />
        </svg>
        <input
          type="text"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          placeholder="Search by email..."
          className="w-full pl-10 pr-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
        />
      </div>

      {/* Stats Card */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
        <div className="text-[12px] text-[#64748B] mb-2 font-medium">Total Admins</div>
        <div className="text-[32px] font-bold text-[#000000]">{users.length}</div>
      </div>

      {/* Admin Users Table */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="bg-[#F8FAFC] border-b border-[#E2E8F0]">
              <tr>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Admin User
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Created
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Last Login
                </th>
                <th className="px-6 py-3 text-right text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-[#E2E8F0]">
              {filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center">
                    <p className="text-[14px] text-[#64748B]">
                      {searchTerm ? 'No admins found matching your search' : 'No admin users yet'}
                    </p>
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user) => (
                  <tr key={user.email} className="hover:bg-[#F8FAFC] transition-colors">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        {user.photoURL ? (
                          <img
                            src={user.photoURL}
                            alt={user.displayName || user.email}
                            className="w-10 h-10 rounded-full mr-3"
                          />
                        ) : (
                          <div className="w-10 h-10 rounded-full bg-[#DBEAFE] flex items-center justify-center text-[#2563EB] text-[14px] font-semibold mr-3">
                            {getInitials(user.email, user.displayName)}
                          </div>
                        )}
                        <div>
                          <div className="text-[14px] font-medium text-[#000000]">
                            {user.displayName || user.email.split('@')[0]}
                            {user.email === currentUser?.email && (
                              <span className="ml-2 text-[11px] text-[#64748B] font-normal">(You)</span>
                            )}
                          </div>
                          <div className="text-[12px] text-[#64748B]">{user.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="inline-flex items-center px-2.5 py-1 rounded-full text-[11px] font-semibold bg-[#DBEAFE] text-[#2563EB]">
                        ADMIN
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-[14px] text-[#64748B]">{formatDate(user.createdAt)}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-[14px] text-[#64748B]">
                        {formatDate(user.lastLoginAt)}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right">
                      <button
                        onClick={() => handleRemoveAdmin(user.email)}
                        disabled={user.email === currentUser?.email}
                        className="inline-flex items-center text-[14px] text-[#DC2626] hover:text-[#B91C1C] transition-colors disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:text-[#DC2626]"
                      >
                        <svg className="w-5 h-5 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                          />
                        </svg>
                        Remove
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Admin Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4">
            <div
              className="fixed inset-0 bg-black/30 backdrop-blur-sm transition-opacity"
              onClick={() => !isAddingAdmin && setShowAddModal(false)}
            ></div>
            <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-8">
              {/* Header */}
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h3 className="text-[24px] font-bold text-[#000000]">Add Admin User</h3>
                  <p className="text-[14px] text-[#64748B] mt-1">
                    Grant admin dashboard access to a new user
                  </p>
                </div>
                <button
                  onClick={() => !isAddingAdmin && setShowAddModal(false)}
                  className="w-10 h-10 rounded-full hover:bg-[#F1F5F9] flex items-center justify-center transition-colors"
                >
                  <svg className="w-6 h-6 text-[#64748B]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              {/* Form */}
              <div className="space-y-4">
                <div>
                  <label htmlFor="adminEmail" className="block text-[13px] font-semibold text-[#000000] mb-2">
                    Email Address
                  </label>
                  <input
                    type="email"
                    id="adminEmail"
                    value={newAdminEmail}
                    onChange={(e) => setNewAdminEmail(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && handleAddAdmin()}
                    placeholder="admin@example.com"
                    className="w-full px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
                    autoFocus
                  />
                  <p className="text-[12px] text-[#64748B] mt-2">
                    The user can sign in with this email using Google authentication.
                  </p>
                </div>

                {/* Actions */}
                <div className="flex items-center justify-end gap-3 pt-4">
                  <button
                    onClick={() => setShowAddModal(false)}
                    disabled={isAddingAdmin}
                    className="px-6 py-2.5 text-[14px] font-medium text-[#64748B] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleAddAdmin}
                    disabled={isAddingAdmin || !newAdminEmail.trim()}
                    className="px-6 py-2.5 text-[14px] font-medium text-white bg-[#2563EB] rounded-lg hover:bg-[#1D4ED8] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                  >
                    {isAddingAdmin ? (
                      <>
                        <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                        <span>Adding...</span>
                      </>
                    ) : (
                      <>
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                        </svg>
                        <span>Add Admin</span>
                      </>
                    )}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
