import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // Primary Colors
        'primary-blue': '#2563EB',
        'deep-navy': '#0F172A',

        // Neutral Colors
        'pure-black': '#000000',
        'dark-gray': '#334155',
        'medium-gray': '#64748B',
        'light-gray': '#94A3B8',
        'off-white': '#F1F5F9',
        'pure-white': '#FFFFFF',

        // Semantic Colors
        'success-green': '#10B981',
        'warning-orange': '#F59E0B',
        'high-green': '#22C55E',
        'info-blue': '#3B82F6',
        'danger-red': '#EF4444',

        // Background & Surface
        'page-bg': '#FAFBFC',
        'card-surface': '#FFFFFF',
        'hover-surface': '#F8FAFC',
        'border-color': '#E2E8F0',
        'disabled-bg': '#F1F5F9',

        // User Avatar
        'avatar-bg': '#DBEAFE',
        'avatar-text': '#2563EB',
      },
      fontSize: {
        'page-heading': ['32px', { lineHeight: '1.2', fontWeight: '700' }],
        'section-heading': ['24px', { lineHeight: '1.3', fontWeight: '600' }],
        'card-title': ['18px', { lineHeight: '1.4', fontWeight: '600' }],
        'body': ['15px', { lineHeight: '1.5', fontWeight: '400' }],
        'small': ['14px', { lineHeight: '1.4', fontWeight: '400' }],
        'micro': ['12px', { lineHeight: '1.3', fontWeight: '400' }],
      },
      spacing: {
        'xs': '4px',
        'sm': '8px',
        'md': '12px',
        'lg': '16px',
        'xl': '24px',
        '2xl': '32px',
        '3xl': '48px',
      },
      borderRadius: {
        'button': '8px',
        'card': '12px',
        'card-lg': '16px',
        'pill': '20px',
      },
      boxShadow: {
        'sm': '0 1px 3px rgba(0, 0, 0, 0.05)',
        'card': '0 1px 3px rgba(0, 0, 0, 0.05)',
        'modal': '0 20px 60px rgba(0, 0, 0, 0.3)',
      },
    },
  },
  plugins: [],
}
export default config
