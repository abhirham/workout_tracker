'use client';

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import {
  User,
  GoogleAuthProvider,
  signInWithPopup,
  signOut as firebaseSignOut,
  onAuthStateChanged
} from 'firebase/auth';
import { doc, getDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase';
import { useRouter } from 'next/navigation';
import { useToast } from './ToastContext';

interface UserData {
  email: string;
  isAdmin: boolean;
  createdAt: any;
  lastLoginAt?: any;
  displayName?: string;
  photoURL?: string;
}

interface AuthContextType {
  user: User | null;
  userData: UserData | null;
  loading: boolean;
  isAdmin: boolean;
  signInWithGoogle: () => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  userData: null,
  loading: true,
  isAdmin: false,
  signInWithGoogle: async () => {},
  signOut: async () => {},
});

export const useAuth = () => useContext(AuthContext);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [userData, setUserData] = useState<UserData | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const toast = useToast();

  // Check if user is admin
  const isAdmin = userData?.isAdmin ?? false;

  // Fetch user data from Firestore
  const fetchUserData = async (user: User): Promise<UserData | null> => {
    try {
      const userDocRef = doc(db, 'users', user.email!);
      const userDoc = await getDoc(userDocRef);

      if (!userDoc.exists()) {
        return null;
      }

      return userDoc.data() as UserData;
    } catch (error) {
      console.error('Error fetching user data:', error);
      return null;
    }
  };

  // Update last login timestamp
  const updateLastLogin = async (email: string) => {
    try {
      const userDocRef = doc(db, 'users', email);
      await updateDoc(userDocRef, {
        lastLoginAt: serverTimestamp(),
      });
    } catch (error) {
      console.error('Error updating last login:', error);
    }
  };

  // Google Sign In
  const signInWithGoogle = async () => {
    try {
      const provider = new GoogleAuthProvider();
      const result = await signInWithPopup(auth, provider);
      const user = result.user;

      if (!user.email) {
        toast.error('Unable to retrieve email from Google account');
        await firebaseSignOut(auth);
        return;
      }

      // Check if user exists in Firestore
      const userData = await fetchUserData(user);

      if (!userData) {
        toast.error('Access denied. Admin access only. Contact an administrator for access.');
        await firebaseSignOut(auth);
        return;
      }

      if (!userData.isAdmin) {
        toast.error('Admin access required. Please use the mobile app instead.');
        await firebaseSignOut(auth);
        return;
      }

      // Update last login
      await updateLastLogin(user.email);

      // Success - will be handled by onAuthStateChanged
      toast.success(`Welcome back, ${user.displayName || user.email}!`);
      router.push('/global-workouts');
    } catch (error: any) {
      console.error('Error signing in with Google:', error);
      if (error.code === 'auth/popup-closed-by-user') {
        toast.error('Sign-in cancelled');
      } else {
        toast.error('Failed to sign in. Please try again.');
      }
    }
  };

  // Sign Out
  const signOut = async () => {
    try {
      await firebaseSignOut(auth);
      setUser(null);
      setUserData(null);
      router.push('/login');
      toast.success('Signed out successfully');
    } catch (error) {
      console.error('Error signing out:', error);
      toast.error('Failed to sign out');
    }
  };

  // Listen to auth state changes
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user && user.email) {
        // Fetch user data from Firestore
        const userData = await fetchUserData(user);

        if (userData && userData.isAdmin) {
          setUser(user);
          setUserData(userData);
        } else {
          // User not authorized or not admin
          setUser(null);
          setUserData(null);
          await firebaseSignOut(auth);
        }
      } else {
        setUser(null);
        setUserData(null);
      }

      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const value: AuthContextType = {
    user,
    userData,
    loading,
    isAdmin,
    signInWithGoogle,
    signOut,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
