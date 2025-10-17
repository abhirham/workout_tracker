'use client';

import type { Metadata } from 'next'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import './globals.css'
import { ToastProvider } from './context/ToastContext'
import { AuthProvider, useAuth } from './context/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'
import { useState } from 'react'

function LayoutContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const { user, userData, signOut } = useAuth()
  const [showUserMenu, setShowUserMenu] = useState(false)

  // Hide navigation on login page
  const isLoginPage = pathname === '/login'

  const navItems = [
    {
      href: '/global-workouts',
      label: 'Workouts',
      icon: (
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M6.5 6.5h11M6.5 17.5h11M3 12h18M6.5 6.5l-3.5 5.5 3.5 5.5M17.5 6.5l3.5 5.5-3.5 5.5"/>
        </svg>
      )
    },
    {
      href: '/workout-plans',
      label: 'Plans',
      icon: (
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="3" width="18" height="18" rx="2"/>
          <path d="M3 9h18M9 3v18"/>
        </svg>
      )
    },
    {
      href: '/users',
      label: 'Users',
      icon: (
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
          <circle cx="9" cy="7" r="4"/>
          <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>
        </svg>
      )
    },
  ]

  return (
    <>
      {/* Navigation Bar - Hide on login page */}
      {!isLoginPage && user && (
        <nav className="bg-white border-b border-[#E2E8F0] h-16">
          <div className="max-w-[1920px] mx-auto px-8 h-full flex items-center justify-between">
            {/* Logo */}
            <div className="flex items-center space-x-2">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" className="text-[#2563EB]">
                <path d="M6.5 6.5h11M6.5 17.5h11M3 12h18M6.5 6.5l-3.5 5.5 3.5 5.5M17.5 6.5l3.5 5.5-3.5 5.5" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              <span className="text-xl font-semibold text-gray-900">FitAdmin</span>
            </div>

            {/* Navigation Items */}
            <div className="flex items-center space-x-1">
              {navItems.map((item) => {
                const isActive = pathname === item.href || (item.href !== '/' && pathname.startsWith(item.href))
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center space-x-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                      isActive
                        ? 'text-[#2563EB] bg-blue-50'
                        : 'text-[#64748B] hover:text-gray-900 hover:bg-gray-50'
                    }`}
                  >
                    {item.icon}
                    <span>{item.label}</span>
                  </Link>
                )
              })}
            </div>

            {/* User Info with Dropdown */}
            <div className="relative">
              <button
                onClick={() => setShowUserMenu(!showUserMenu)}
                className="flex items-center space-x-3 hover:bg-gray-50 px-3 py-2 rounded-lg transition-colors"
              >
                <div className="text-right">
                  <div className="text-sm font-medium text-gray-900">
                    {userData?.displayName || user?.displayName || 'Admin'}
                  </div>
                  <div className="text-xs text-[#64748B]">{user?.email}</div>
                </div>
                {user?.photoURL ? (
                  <img
                    src={user.photoURL}
                    alt="Profile"
                    className="w-10 h-10 rounded-full"
                  />
                ) : (
                  <div className="w-10 h-10 rounded-full bg-[#DBEAFE] flex items-center justify-center text-[#2563EB] font-semibold text-sm">
                    {(userData?.displayName || user?.displayName || user?.email || 'A')[0].toUpperCase()}
                  </div>
                )}
                <svg className={`w-4 h-4 text-[#64748B] transition-transform ${showUserMenu ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              {/* Dropdown Menu */}
              {showUserMenu && (
                <>
                  <div
                    className="fixed inset-0 z-10"
                    onClick={() => setShowUserMenu(false)}
                  />
                  <div className="absolute right-0 mt-2 w-56 bg-white rounded-lg shadow-lg border border-[#E2E8F0] py-2 z-20">
                    <div className="px-4 py-3 border-b border-[#E2E8F0]">
                      <p className="text-[13px] font-semibold text-[#000000]">
                        {userData?.displayName || user?.displayName || 'Admin'}
                      </p>
                      <p className="text-[12px] text-[#64748B] mt-0.5">{user?.email}</p>
                      <span className="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold bg-[#DBEAFE] text-[#2563EB] mt-2">
                        ADMIN
                      </span>
                    </div>
                    <button
                      onClick={signOut}
                      className="w-full px-4 py-2 text-left text-[14px] text-[#DC2626] hover:bg-[#FEF2F2] transition-colors flex items-center gap-2"
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                      </svg>
                      Sign Out
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </nav>
      )}

      {/* Main Content */}
      <main className={isLoginPage ? '' : 'bg-[#FAFBFC] min-h-[calc(100vh-4rem)]'}>
        {isLoginPage ? (
          children
        ) : (
          <div className="max-w-[1920px] mx-auto px-8 py-8">
            {children}
          </div>
        )}
      </main>
    </>
  )
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <head>
        <title>FitAdmin - Workout Tracker</title>
        <meta name="description" content="Admin dashboard for managing workout plans and exercises" />
      </head>
      <body className="bg-white min-h-screen">
        <ToastProvider>
          <AuthProvider>
            <ProtectedRoute>
              <LayoutContent>{children}</LayoutContent>
            </ProtectedRoute>
          </AuthProvider>
        </ToastProvider>
      </body>
    </html>
  )
}
