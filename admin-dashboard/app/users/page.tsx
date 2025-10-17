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

interface User {
  email: string;
  isAdmin: boolean;
  isActive: boolean;
  createdAt: any;
  lastLoginAt?: any;
  displayName?: string;
  photoURL?: string;
}

export default function UsersPage() {
  const toast = useToast();
  const { user: currentUser } = useAuth();
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [newUserEmail, setNewUserEmail] = useState('');
  const [newUserIsAdmin, setNewUserIsAdmin] = useState(false);
  const [isAddingUser, setIsAddingUser] = useState(false);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [editIsAdmin, setEditIsAdmin] = useState(false);
  const [editIsActive, setEditIsActive] = useState(true);
  const [isUpdatingUser, setIsUpdatingUser] = useState(false);

  useEffect(() => {
    // Real-time listener for users collection
    const q = query(collection(db, 'users'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const usersData = snapshot.docs.map((doc) => ({
          email: doc.id,
          ...doc.data(),
        })) as User[];
        setUsers(usersData);
        setLoading(false);
      },
      (error) => {
        console.error('Error fetching users:', error);
        toast.error('Failed to fetch users');
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [toast]);

  const handleAddUser = async () => {
    if (!newUserEmail.trim()) {
      toast.error('Please enter an email address');
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(newUserEmail.trim())) {
      toast.error('Please enter a valid email address');
      return;
    }

    // Check if user already exists
    const existingUser = users.find(
      (u) => u.email.toLowerCase() === newUserEmail.trim().toLowerCase()
    );
    if (existingUser) {
      toast.warning('This email already exists in the system');
      return;
    }

    setIsAddingUser(true);
    try {
      const userDocRef = doc(db, 'users', newUserEmail.trim());
      await setDoc(userDocRef, {
        email: newUserEmail.trim(),
        isAdmin: newUserIsAdmin,
        isActive: true,
        createdAt: serverTimestamp(),
      });

      const userType = newUserIsAdmin ? 'Admin' : 'User';
      toast.success(`${userType} added successfully`);
      setNewUserEmail('');
      setNewUserIsAdmin(false);
      setShowAddModal(false);
    } catch (error) {
      console.error('Error adding user:', error);
      toast.error('Failed to add user');
    } finally {
      setIsAddingUser(false);
    }
  };

  const handleEditUser = (user: User) => {
    if (user.email === currentUser?.email) {
      toast.error('You cannot edit your own account');
      return;
    }

    setEditingUser(user);
    setEditIsAdmin(user.isAdmin);
    setEditIsActive(user.isActive);
    setShowEditModal(true);
  };

  const handleSaveEdit = async () => {
    if (!editingUser) return;

    setIsUpdatingUser(true);
    try {
      const userDocRef = doc(db, 'users', editingUser.email);
      const wasAdmin = editingUser.isAdmin;

      // Build update object, only including fields that exist
      const updateData: any = {
        email: editingUser.email,
        isAdmin: editIsAdmin,
        isActive: editIsActive,
        createdAt: editingUser.createdAt,
      };

      // Only include optional fields if they exist
      if (editingUser.lastLoginAt !== undefined) {
        updateData.lastLoginAt = editingUser.lastLoginAt;
      }
      if (editingUser.displayName !== undefined) {
        updateData.displayName = editingUser.displayName;
      }
      if (editingUser.photoURL !== undefined) {
        updateData.photoURL = editingUser.photoURL;
      }

      await setDoc(userDocRef, updateData);

      toast.success('User updated successfully');

      // If admin status was revoked, show additional warning
      if (wasAdmin && !editIsAdmin) {
        toast.warning(`Admin access revoked - user will be signed out on next authentication check`);
      }

      setShowEditModal(false);
      setEditingUser(null);
    } catch (error) {
      console.error('Error updating user:', error);
      toast.error('Failed to update user');
    } finally {
      setIsUpdatingUser(false);
    }
  };

  const handleRemoveUser = async (user: User) => {
    // Prevent self-deletion
    if (user.email === currentUser?.email) {
      toast.error('You cannot remove yourself');
      return;
    }

    const userType = user.isAdmin ? 'Admin' : 'User';
    const status = user.isActive ? 'Active' : 'Inactive';

    if (!confirm(`Are you sure you want to remove ${status} ${userType}: ${user.email}?`)) {
      return;
    }

    try {
      const userDocRef = doc(db, 'users', user.email);
      await deleteDoc(userDocRef);
      toast.success(`${userType} removed successfully`);
    } catch (error) {
      console.error('Error removing user:', error);
      toast.error('Failed to remove user');
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
          <p className="text-[14px] text-[#64748B] font-medium">Loading users...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-[32px] font-bold text-[#000000] leading-[1.2]">User Management</h1>
          <p className="text-[14px] text-[#64748B] mt-1">
            Manage all users and their access levels
          </p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="px-4 py-2.5 bg-[#2563EB] text-white text-[14px] font-medium rounded-lg hover:bg-[#1D4ED8] transition-colors flex items-center gap-2"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
          Add User
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

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
          <div className="text-[12px] text-[#64748B] mb-2 font-medium">Total Users</div>
          <div className="text-[32px] font-bold text-[#000000]">{users.length}</div>
        </div>
        <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
          <div className="text-[12px] text-[#64748B] mb-2 font-medium">Admins</div>
          <div className="text-[32px] font-bold text-[#2563EB]">{users.filter(u => u.isAdmin).length}</div>
        </div>
        <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
          <div className="text-[12px] text-[#64748B] mb-2 font-medium">Regular Users</div>
          <div className="text-[32px] font-bold text-[#10B981]">{users.filter(u => !u.isAdmin).length}</div>
        </div>
        <div className="bg-white rounded-lg border border-[#E2E8F0] p-6">
          <div className="text-[12px] text-[#64748B] mb-2 font-medium">Active</div>
          <div className="text-[32px] font-bold text-[#10B981]">{users.filter(u => u.isActive).length}</div>
          <div className="text-[12px] text-[#94A3B8] mt-1">Inactive: {users.filter(u => !u.isActive).length}</div>
        </div>
      </div>

      {/* Admin Users Table */}
      <div className="bg-white rounded-lg border border-[#E2E8F0] overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="bg-[#F8FAFC] border-b border-[#E2E8F0]">
              <tr>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  User
                </th>
                <th className="px-6 py-3 text-left text-[11px] font-semibold text-[#64748B] uppercase tracking-wider">
                  Role
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
                  <td colSpan={6} className="px-6 py-12 text-center">
                    <p className="text-[14px] text-[#64748B]">
                      {searchTerm ? 'No users found matching your search' : 'No users yet'}
                    </p>
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user) => (
                  <tr key={user.email} className={`hover:bg-[#F8FAFC] transition-colors ${!user.isActive ? 'opacity-60' : ''}`}>
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
                      <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-[11px] font-semibold ${
                        user.isAdmin
                          ? 'bg-[#DBEAFE] text-[#2563EB]'
                          : 'bg-[#F0FDF4] text-[#10B981]'
                      }`}>
                        {user.isAdmin ? 'ADMIN' : 'USER'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center gap-2">
                        <div className={`w-2 h-2 rounded-full ${user.isActive ? 'bg-[#10B981]' : 'bg-[#94A3B8]'}`}></div>
                        <span className="text-[14px] text-[#64748B]">
                          {user.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </div>
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
                      <div className="flex items-center justify-end gap-3">
                        <button
                          onClick={() => handleEditUser(user)}
                          disabled={user.email === currentUser?.email}
                          className="inline-flex items-center text-[14px] text-[#2563EB] hover:text-[#1D4ED8] transition-colors disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:text-[#2563EB]"
                          title={user.email === currentUser?.email ? 'Cannot edit yourself' : 'Edit user'}
                        >
                          <svg className="w-5 h-5 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={2}
                              d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                            />
                          </svg>
                          Edit
                        </button>
                        <button
                          onClick={() => handleRemoveUser(user)}
                          disabled={user.email === currentUser?.email}
                          className="inline-flex items-center text-[14px] text-[#DC2626] hover:text-[#B91C1C] transition-colors disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:text-[#DC2626]"
                          title={user.email === currentUser?.email ? 'Cannot remove yourself' : 'Remove user'}
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
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add User Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4">
            <div
              className="fixed inset-0 bg-black/30 backdrop-blur-sm transition-opacity"
              onClick={() => !isAddingUser && setShowAddModal(false)}
            ></div>
            <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-8">
              {/* Header */}
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h3 className="text-[24px] font-bold text-[#000000]">Add User</h3>
                  <p className="text-[14px] text-[#64748B] mt-1">
                    Add a new user to the system
                  </p>
                </div>
                <button
                  onClick={() => !isAddingUser && setShowAddModal(false)}
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
                  <label htmlFor="userEmail" className="block text-[13px] font-semibold text-[#000000] mb-2">
                    Email Address
                  </label>
                  <input
                    type="email"
                    id="userEmail"
                    value={newUserEmail}
                    onChange={(e) => setNewUserEmail(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && handleAddUser()}
                    placeholder="user@example.com"
                    className="w-full px-4 py-2.5 border border-[#E2E8F0] rounded-lg text-[14px] bg-white focus:outline-none focus:ring-2 focus:ring-[#2563EB] focus:border-transparent"
                    autoFocus
                  />
                </div>

                {/* User Type Selection */}
                <div>
                  <label className="block text-[13px] font-semibold text-[#000000] mb-3">
                    User Type
                  </label>
                  <div className="space-y-2">
                    <label className="flex items-center p-3 border border-[#E2E8F0] rounded-lg cursor-pointer hover:bg-[#F8FAFC] transition-colors">
                      <input
                        type="radio"
                        name="userType"
                        checked={!newUserIsAdmin}
                        onChange={() => setNewUserIsAdmin(false)}
                        className="w-4 h-4 text-[#2563EB] focus:ring-2 focus:ring-[#2563EB]"
                      />
                      <div className="ml-3">
                        <div className="text-[14px] font-medium text-[#000000]">Regular User</div>
                        <div className="text-[12px] text-[#64748B]">Can access mobile app only</div>
                      </div>
                    </label>
                    <label className="flex items-center p-3 border border-[#E2E8F0] rounded-lg cursor-pointer hover:bg-[#F8FAFC] transition-colors">
                      <input
                        type="radio"
                        name="userType"
                        checked={newUserIsAdmin}
                        onChange={() => setNewUserIsAdmin(true)}
                        className="w-4 h-4 text-[#2563EB] focus:ring-2 focus:ring-[#2563EB]"
                      />
                      <div className="ml-3">
                        <div className="text-[14px] font-medium text-[#000000]">Admin</div>
                        <div className="text-[12px] text-[#64748B]">Can access dashboard and manage system</div>
                      </div>
                    </label>
                  </div>
                </div>

                {/* Actions */}
                <div className="flex items-center justify-end gap-3 pt-4">
                  <button
                    onClick={() => setShowAddModal(false)}
                    disabled={isAddingUser}
                    className="px-6 py-2.5 text-[14px] font-medium text-[#64748B] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleAddUser}
                    disabled={isAddingUser || !newUserEmail.trim()}
                    className="px-6 py-2.5 text-[14px] font-medium text-white bg-[#2563EB] rounded-lg hover:bg-[#1D4ED8] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                  >
                    {isAddingUser ? (
                      <>
                        <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                        <span>Adding...</span>
                      </>
                    ) : (
                      <>
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                        </svg>
                        <span>Add User</span>
                      </>
                    )}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Edit User Modal */}
      {showEditModal && editingUser && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex min-h-full items-center justify-center p-4">
            <div
              className="fixed inset-0 bg-black/30 backdrop-blur-sm transition-opacity"
              onClick={() => !isUpdatingUser && setShowEditModal(false)}
            ></div>
            <div className="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-8">
              {/* Header */}
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h3 className="text-[24px] font-bold text-[#000000]">Edit User</h3>
                  <p className="text-[14px] text-[#64748B] mt-1">
                    Modify user access and status
                  </p>
                </div>
                <button
                  onClick={() => !isUpdatingUser && setShowEditModal(false)}
                  className="w-10 h-10 rounded-full hover:bg-[#F1F5F9] flex items-center justify-center transition-colors"
                >
                  <svg className="w-6 h-6 text-[#64748B]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              {/* User Info */}
              <div className="mb-6 p-4 bg-[#F8FAFC] rounded-lg">
                <div className="flex items-center">
                  {editingUser.photoURL ? (
                    <img
                      src={editingUser.photoURL}
                      alt={editingUser.displayName || editingUser.email}
                      className="w-12 h-12 rounded-full mr-3"
                    />
                  ) : (
                    <div className="w-12 h-12 rounded-full bg-[#DBEAFE] flex items-center justify-center text-[#2563EB] text-[16px] font-semibold mr-3">
                      {getInitials(editingUser.email, editingUser.displayName)}
                    </div>
                  )}
                  <div>
                    <div className="text-[16px] font-semibold text-[#000000]">
                      {editingUser.displayName || editingUser.email.split('@')[0]}
                    </div>
                    <div className="text-[13px] text-[#64748B]">{editingUser.email}</div>
                  </div>
                </div>
              </div>

              {/* Form */}
              <div className="space-y-4">
                {/* Admin Status Toggle */}
                <div className="p-4 border border-[#E2E8F0] rounded-lg">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="text-[14px] font-semibold text-[#000000]">Admin Access</div>
                      <div className="text-[12px] text-[#64748B] mt-0.5">
                        Grant dashboard access and management permissions
                      </div>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        checked={editIsAdmin}
                        onChange={(e) => setEditIsAdmin(e.target.checked)}
                        className="sr-only peer"
                      />
                      <div className="w-11 h-6 bg-[#E2E8F0] peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-[#DBEAFE] rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-[#2563EB]"></div>
                    </label>
                  </div>
                </div>

                {/* Active Status Toggle */}
                <div className="p-4 border border-[#E2E8F0] rounded-lg">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="text-[14px] font-semibold text-[#000000]">Active Account</div>
                      <div className="text-[12px] text-[#64748B] mt-0.5">
                        Inactive users cannot sign in
                      </div>
                    </div>
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        checked={editIsActive}
                        onChange={(e) => setEditIsActive(e.target.checked)}
                        className="sr-only peer"
                      />
                      <div className="w-11 h-6 bg-[#E2E8F0] peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-[#DBEAFE] rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-[#10B981]"></div>
                    </label>
                  </div>
                </div>

                {/* Actions */}
                <div className="flex items-center justify-end gap-3 pt-4">
                  <button
                    onClick={() => setShowEditModal(false)}
                    disabled={isUpdatingUser}
                    className="px-6 py-2.5 text-[14px] font-medium text-[#64748B] bg-white border border-[#E2E8F0] rounded-lg hover:bg-[#F8FAFC] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleSaveEdit}
                    disabled={isUpdatingUser}
                    className="px-6 py-2.5 text-[14px] font-medium text-white bg-[#2563EB] rounded-lg hover:bg-[#1D4ED8] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                  >
                    {isUpdatingUser ? (
                      <>
                        <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                        <span>Saving...</span>
                      </>
                    ) : (
                      <>
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                        <span>Save Changes</span>
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
