'use client';

import { useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { useRouter, usePathname } from 'next/navigation';

export default function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading, isAdmin } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    // Don't redirect if we're already on the login page
    if (pathname === '/login') {
      return;
    }

    // If not loading and no user, redirect to login
    if (!loading && !user) {
      router.push('/login');
    }

    // If user exists but is not admin, redirect to login
    if (!loading && user && !isAdmin) {
      router.push('/login');
    }
  }, [user, loading, isAdmin, router, pathname]);

  // Show loading spinner while checking auth
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#FAFBFC]">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-[#2563EB] border-t-transparent rounded-full animate-spin"></div>
          <p className="text-[14px] text-[#64748B]">Loading...</p>
        </div>
      </div>
    );
  }

  // Don't render protected content if user is not authenticated or not admin
  if (!user || !isAdmin) {
    if (pathname === '/login') {
      return <>{children}</>;
    }
    return null;
  }

  return <>{children}</>;
}
