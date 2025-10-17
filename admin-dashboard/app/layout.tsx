'use client';

import type { Metadata } from 'next'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import './globals.css'
import { ToastProvider } from './context/ToastContext'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()

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
    <html lang="en">
      <head>
        <title>FitAdmin - Workout Tracker</title>
        <meta name="description" content="Admin dashboard for managing workout plans and exercises" />
      </head>
      <body className="bg-white min-h-screen">
        <ToastProvider>
          {/* Navigation Bar */}
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

              {/* User Info */}
              <div className="flex items-center space-x-3">
                <div className="text-right">
                  <div className="text-sm font-medium text-gray-900">Admin User</div>
                  <div className="text-xs text-[#64748B]">admin@fitapp.com</div>
                </div>
                <div className="w-10 h-10 rounded-full bg-[#DBEAFE] flex items-center justify-center text-[#2563EB] font-semibold text-sm">
                  AU
                </div>
              </div>
            </div>
          </nav>

          {/* Main Content */}
          <main className="bg-[#FAFBFC] min-h-[calc(100vh-4rem)]">
            <div className="max-w-[1920px] mx-auto px-8 py-8">
              {children}
            </div>
          </main>
        </ToastProvider>
      </body>
    </html>
  )
}
