import Link from 'next/link'

export default function Home() {
  const features = [
    {
      title: 'Global Workouts',
      description: 'Manage the global exercise library. All workout plans reference exercises from this library.',
      href: '/global-workouts',
      stats: { label: 'Total Exercises', value: '150+' }
    },
    {
      title: 'Workout Plans',
      description: 'Create and manage workout plans with weeks, days, and exercises. Configure progressive overload settings.',
      href: '/workout-plans',
      stats: { label: 'Active Plans', value: '25+' }
    },
    {
      title: 'Users',
      description: 'View and manage users, track their progress, and monitor workout completion rates.',
      href: '/users',
      stats: { label: 'Active Users', value: '3,842' }
    },
  ]

  const quickStats = [
    { label: 'Total Workouts', value: '1,247', change: '+12%' },
    { label: 'Active Users', value: '3,842', change: '+23%' },
    { label: 'Plans Created', value: '156', change: '+8%' },
    { label: 'Completion Rate', value: '87%', change: '+5%' },
  ]

  return (
    <div className="space-y-8 max-w-7xl">
      {/* Hero Section */}
      <div className="mb-8">
        <h1 className="text-page-heading text-pure-black mb-3">
          Welcome Back!
        </h1>
        <p className="text-body text-[#64748B] max-w-3xl">
          Manage your workout ecosystem from a single, powerful dashboard. Create exercises, build plans, and track progress.
        </p>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {quickStats.map((stat, index) => (
          <div
            key={index}
            className="card p-6"
          >
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm text-[#64748B] font-normal">
                {stat.label}
              </h3>
              <span className="text-xs font-semibold text-[#10B981] bg-[#D1FAE5] px-2.5 py-1 rounded-full">
                {stat.change}
              </span>
            </div>
            <p className="text-3xl font-bold text-pure-black">{stat.value}</p>
          </div>
        ))}
      </div>

      {/* Main Features */}
      <div>
        <h2 className="text-section-heading text-pure-black mb-6">Quick Actions</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, index) => (
            <Link
              key={index}
              href={feature.href}
              className="card card-hover p-6 block"
            >
              {/* Content */}
              <h3 className="text-card-title text-pure-black mb-3">
                {feature.title}
              </h3>
              <p className="text-small text-[#64748B] mb-6 leading-relaxed">
                {feature.description}
              </p>

              {/* Stats */}
              <div className="flex items-center justify-between pt-5 border-t border-[#F1F5F9]">
                <div>
                  <p className="text-xs text-[#64748B] font-medium uppercase tracking-wide mb-1">
                    {feature.stats.label}
                  </p>
                  <p className="text-2xl font-bold text-pure-black">
                    {feature.stats.value}
                  </p>
                </div>
                <div className="flex items-center text-[#2563EB] font-medium text-sm">
                  <span>View</span>
                  <svg className="w-4 h-4 ml-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
                  </svg>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </div>

      {/* Getting Started Guide */}
      <div className="card p-8 bg-[#F8FAFC]">
        <h2 className="text-xl font-semibold text-pure-black mb-6">Getting Started</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="flex items-start space-x-4">
            <div className="flex-shrink-0 w-8 h-8 rounded-full bg-[#0F172A] text-white flex items-center justify-center font-semibold text-sm">1</div>
            <div>
              <h3 className="font-semibold text-pure-black mb-1.5">Create Global Workouts</h3>
              <p className="text-sm text-[#64748B]">Build your exercise library with detailed configurations</p>
            </div>
          </div>
          <div className="flex items-start space-x-4">
            <div className="flex-shrink-0 w-8 h-8 rounded-full bg-[#0F172A] text-white flex items-center justify-center font-semibold text-sm">2</div>
            <div>
              <h3 className="font-semibold text-pure-black mb-1.5">Design Workout Plans</h3>
              <p className="text-sm text-[#64748B]">Organize exercises into structured weekly programs</p>
            </div>
          </div>
          <div className="flex items-start space-x-4">
            <div className="flex-shrink-0 w-8 h-8 rounded-full bg-[#0F172A] text-white flex items-center justify-center font-semibold text-sm">3</div>
            <div>
              <h3 className="font-semibold text-pure-black mb-1.5">Track Progress</h3>
              <p className="text-sm text-[#64748B]">Monitor user engagement and workout completion</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
