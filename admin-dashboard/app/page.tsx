export default function Home() {
  return (
    <div className="px-4 py-6 sm:px-0">
      <div className="border-4 border-dashed border-gray-200 rounded-lg p-8">
        <h2 className="text-3xl font-bold text-gray-900 mb-4">
          Welcome to Workout Tracker Admin
        </h2>
        <p className="text-gray-600 mb-6">
          Manage your workout templates, global exercises, and workout plans from this dashboard.
        </p>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
          <div className="bg-white p-6 rounded-lg shadow">
            <h3 className="text-xl font-semibold text-gray-900 mb-2">
              Global Workouts
            </h3>
            <p className="text-gray-600 mb-4">
              Create and manage the library of exercises that can be used across all workout plans.
            </p>
            <a
              href="/global-workouts"
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-primary-600 hover:bg-primary-700"
            >
              Manage Workouts
            </a>
          </div>

          <div className="bg-white p-6 rounded-lg shadow">
            <h3 className="text-xl font-semibold text-gray-900 mb-2">
              Workout Plans
            </h3>
            <p className="text-gray-600 mb-4">
              Create structured workout plans with weeks, days, and exercises for your users.
            </p>
            <a
              href="/workout-plans"
              className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-primary-600 hover:bg-primary-700"
            >
              Manage Plans
            </a>
          </div>
        </div>
      </div>
    </div>
  )
}
