# Workout Tracker Admin Dashboard

Admin dashboard for managing workout templates, global exercises, and workout plans.

## Features

- **Global Workouts Management**: Create and manage the library of exercises
- **Workout Plans**: Create structured plans with weeks, days, and exercises
- **Real-time Sync**: Changes sync immediately to Firestore and mobile apps
- **Responsive Design**: Works on desktop and mobile devices

## Setup

1. **Install dependencies:**
   ```bash
   cd admin-dashboard
   npm install
   ```

2. **Configure Firebase:**
   - Copy `.env.local.example` to `.env.local`
   - Add your Firebase configuration values
   - Get these values from Firebase Console > Project Settings

3. **Run development server:**
   ```bash
   npm run dev
   ```

4. **Build for production:**
   ```bash
   npm run build
   ```

## Firebase Configuration

Create a `.env.local` file with your Firebase credentials:

```bash
NEXT_PUBLIC_FIREBASE_API_KEY=your-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=bodyfit-b1563.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=bodyfit-b1563
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=bodyfit-b1563.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=578179837108
NEXT_PUBLIC_FIREBASE_APP_ID=1:578179837108:web:2a7adee6baad9494fd7be1
```

## Usage

### Global Workouts

1. Navigate to "Global Workouts"
2. Click "Add Workout"
3. Enter workout details:
   - Name (e.g., "Bench Press")
   - Type (weight or timer)
   - Muscle groups (comma-separated)
   - Equipment (comma-separated)
   - Search keywords (comma-separated)
4. Click "Create"

### Workout Plans

1. Navigate to "Workout Plans"
2. Click "Create Plan"
3. Enter plan name and description
4. Click "Manage Weeks" to add structure:
   - Add Weeks (e.g., Week 1, Week 2)
   - Add Days to each week (e.g., Day 1: Push, Day 2: Pull)
   - Add Workouts to each day:
     - Select from global workouts library
     - Configure base weights, target reps, rest timers
     - Add notes

## Data Structure

### Firestore Collections

```
/global_workouts/{workoutId}
  - id, name, type, muscleGroups[], equipment[], searchKeywords[], isActive

/workout_plans/{planId}
  - name, description, isActive

  /weeks/{weekId}
    - weekNumber, name

    /days/{dayId}
      - dayNumber, name

      /workouts/{workoutId}
        - globalWorkoutId, name, order, baseWeights[], targetReps,
          restTimerSeconds, notes, alternativeWorkouts[]
```

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth (to be implemented)
- **Deployment**: Firebase Hosting

## Development

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run lint` - Run ESLint

## Deployment

To deploy to Firebase Hosting:

```bash
npm run build
firebase deploy --only hosting
```

## Notes

- All workouts created here sync to mobile apps automatically
- Global workouts are shared across all workout plans
- Workout plans follow a nested structure: Plan → Week → Day → Workout
- Use the autocomplete dropdown to select exercises from the global library
