# Workout Tracker Admin Dashboard

Admin web dashboard for managing workout plans and the global exercise library for the Workout Tracker mobile app.

## Tech Stack

- **Next.js 15.5.4** - React framework with App Router
- **React 19.2.0** - UI library
- **TypeScript 5.9.3** - Type safety
- **Tailwind CSS 4.1.14** - Styling
- **Firebase 12.4.0** - Backend (Firestore, Auth)

## Project Structure

```
admin-dashboard/
├── app/                    # Next.js App Router pages
│   ├── layout.tsx          # Root layout with navigation
│   ├── page.tsx            # Dashboard home
│   ├── global-workouts/    # Exercise library CRUD
│   └── workout-plans/      # Workout plan management
│       ├── page.tsx        # Plans list
│       └── [planId]/       # Detailed plan editor
│           └── page.tsx    # Nested weeks/days/workouts
├── lib/
│   └── firebase.ts         # Firebase client configuration
├── package.json
├── tsconfig.json
├── tailwind.config.ts
├── postcss.config.js
├── next.config.js
└── .env.local.example      # Environment variables template

```

## Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Firebase

Create a `.env.local` file in the root directory:

```bash
cp .env.local.example .env.local
```

Edit `.env.local` and add your Firebase project credentials:

```env
NEXT_PUBLIC_FIREBASE_API_KEY=your_api_key_here
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your_project_id.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your_project_id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your_project_id.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=your_sender_id
NEXT_PUBLIC_FIREBASE_APP_ID=your_app_id
```

**To get Firebase credentials:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings > General
4. Scroll to "Your apps" section
5. Click the web app icon (</>) to create a web app if you haven't
6. Copy the config values to `.env.local`

### 3. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### 4. Build for Production

```bash
npm run build
npm start
```

## Features

### Global Workouts Management

- **CRUD operations** for exercise library
- Exercise properties:
  - Name (e.g., "Bench Press", "Plank")
  - Type: weight or timer
  - Muscle groups (array)
  - Equipment (array)
  - Search keywords (array)
  - Active/Inactive status
- All workout plans reference exercises from this library

### Workout Plans Management

- **CRUD operations** for workout plans
- Plan properties:
  - Name
  - Description
  - Total weeks
  - Active/Inactive status

### Detailed Plan Editor

- **Three-column layout** for nested structure:

  - Column 1: Weeks
  - Column 2: Days (for selected week)
  - Column 3: Workouts (for selected day)

- **Workout configuration:**

  - Select from global workouts library
  - Order within day
  - Notes
  - Base weights (for progressive overload)
  - Target reps
  - Rest timer duration (seconds)
  - Workout duration (for timer-based exercises)
  - Alternative workout IDs

- **Nested CRUD:**
  - Create/Edit/Delete weeks within a plan
  - Create/Edit/Delete days within a week
  - Create/Edit/Delete workouts within a day

## Firestore Data Model

### Collections

```
/global_workouts/{workoutId}
  - name: string
  - type: 'weight' | 'timer'
  - muscleGroups: string[]
  - equipment: string[]
  - searchKeywords: string[]
  - isActive: boolean
  - createdAt: Timestamp
  - updatedAt: Timestamp

/workout_plans/{planId}
  - name: string
  - description: string
  - totalWeeks: number
  - isActive: boolean
  - createdAt: Timestamp
  - updatedAt: Timestamp

  /weeks/{weekId}
    - weekNumber: number
    - name: string
    - createdAt: Timestamp
    - updatedAt: Timestamp

    /days/{dayId}
      - dayNumber: number
      - name: string
      - createdAt: Timestamp
      - updatedAt: Timestamp

      /workouts/{workoutId}
        - globalWorkoutId: string (references /global_workouts)
        - name: string
        - order: number
        - notes: string
        - baseWeights: number[]
        - targetReps: number | null
        - restTimerSeconds: number | null
        - workoutDurationSeconds: number | null
        - alternativeWorkouts: string[]
        - createdAt: Timestamp
        - updatedAt: Timestamp
```

## Development

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run lint` - Run ESLint

### Code Style

- Use TypeScript for all components
- Use 'use client' directive for client components
- Follow Next.js App Router conventions
- Use Tailwind CSS for styling
- Use Firestore SDK directly (no abstraction layer yet)

## Deployment

This dashboard can be deployed to:

- **Firebase Hosting** (recommended, same project as backend)
- **Vercel** (optimized for Next.js)
- **Netlify**
- Any static hosting service (supports static export)

### Deploy to Firebase Hosting

```bash
npm run build
firebase deploy --only hosting
```

## Security

- Admin dashboard should be protected by Firebase Authentication
- Implement admin role checks in Firebase Security Rules
- Never commit `.env.local` to version control
- Use environment variables for all sensitive data

### Recommended Firebase Security Rules

```javascript
// Global workouts (read-only for users, write for admins)
match /global_workouts/{workoutId} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;
}

// Workout plans (read-only for users, write for admins)
match /workout_plans/{planId} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;

  match /weeks/{weekId} {
    allow read: if request.auth != null;
    allow write: if request.auth.token.admin == true;

    match /days/{dayId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;

      match /workouts/{workoutId} {
        allow read: if request.auth != null;
        allow write: if request.auth.token.admin == true;
      }
    }
  }
}
```

## Next Steps

- [ ] Add Firebase Authentication (admin login)
- [ ] Add user management page
- [ ] Add bulk operations (create multiple weeks at once)
- [ ] Add import/export functionality (JSON/CSV)
- [ ] Add workout plan templates
- [ ] Add analytics dashboard
- [ ] Add search/filter functionality
- [ ] Add drag-and-drop reordering
- [ ] Add preview mode (see what users will see)

## Support

For issues or questions, please refer to the main project documentation or create an issue in the project repository.

I tried:

- rm -rf Pods Podfile.lock .symlinks -> pod install
- flutter doctor -v -> flutter precache --ios -> cd /Users/abhirhamsavarap/Projects/STS/workout_tracker/ios -> rm -rf Flutter/Flutter.framework Flutter/Flutter.xcframework -> ln -s /Users/abhirhamsavarap/Development/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework Flutter/Flutter.xcframework -> update ios/Podfile with: `# Point to Flutter
flutter_application_path = '/Users/abhirhamsavarap/Projects/STS/workout_tracker'
engine_dir = File.join('/Users/abhirhamsavarap/Development/flutter', 'bin', 'cache', 'artifacts', 'engine')` -> flutter clean -> rm -rf Pods Podfile.lock .symlinks ~/Library/Developer/Xcode/DerivedData/\* -> pod cache clean --all -> pod install --verbose -> flutter pub get -> pod install
- cd /Users/abhirhamsavarap/Projects/STS/workout_tracker -> flutter clean -> cd ios -> rm -rf Pods -> rm -rf .symlinks -> rm -rf Flutter/Flutter.framework -> rm -rf Flutter/Flutter.xcframework -> rm Podfile.lock -> rm -rf ~/Library/Developer/Xcode/DerivedData/\* -> flutter doctor -v -> which flutter -> flutter --version -> flutter create . --platforms=ios -> pod repo update -> pod install --repo-update -> flutter pub get -> pod install
