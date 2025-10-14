# Workout Tracker - Monorepo

A comprehensive workout tracking system with a Flutter mobile app and Next.js admin dashboard.

## Project Structure

```
/
├── workout_tracker/     # Flutter mobile app
│   ├── lib/            # Dart source code
│   ├── android/        # Android platform code
│   ├── ios/            # iOS platform code
│   └── pubspec.yaml    # Flutter dependencies
│
├── admin-dashboard/     # Next.js admin dashboard
│   ├── app/            # Next.js app directory
│   ├── components/     # React components
│   └── package.json    # Node dependencies
│
├── claude.md           # Project documentation
└── todo.md             # Development todos
```

## Tech Stack

### Mobile App (workout_tracker/)
- **Framework**: Flutter 3.x
- **State Management**: flutter_riverpod
- **Local Database**: Drift (SQLite)
- **Backend**: Firebase (Firestore, Auth)
- **Navigation**: go_router

### Admin Dashboard (admin-dashboard/)
- **Framework**: Next.js 15.x (React)
- **Styling**: Tailwind CSS
- **Backend**: Firebase (Firestore, Auth, Hosting)
- **Language**: TypeScript

## Getting Started

### Mobile App

```bash
cd workout_tracker
flutter pub get
flutter run
```

### Admin Dashboard

```bash
cd admin-dashboard
npm install
npm run dev
```

Access the dashboard at: http://localhost:3001

## Features

### Mobile App
- Offline-first workout tracking
- Progressive overload calculation
- Rest timers and workout timers
- Workout alternatives
- Firebase sync

### Admin Dashboard
- Global workouts library management
- Workout plan builder with weeks/days/workouts
- User management
- Analytics and progress tracking

## Documentation

See `claude.md` for detailed project architecture, data models, and development guidelines.

## License

Private project - All rights reserved
