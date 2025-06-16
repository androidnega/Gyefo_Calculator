# Gyefo Clocking App

A Flutter application for employee time tracking with role-based authentication and Firebase integration.

## Features

- **Role-based Authentication**: Manager and Worker roles with different permissions
- **Clock In/Out System**: Workers can clock in and out with timestamp tracking
- **Manager Dashboard**: Create worker accounts and view attendance records
- **Worker Dashboard**: Simple interface for clocking in/out and viewing personal records
- **Attendance Tracking**: Detailed attendance records with hours worked calculation
- **Secure Firestore Rules**: Role-based data access control

## Demo Accounts

For testing purposes, you can create demo accounts using the built-in setup tool:

### Method 1: Using the App (Recommended)
1. Run the app in debug mode
2. On the login screen, tap the "Demo Setup" button (only visible in debug mode)
3. Tap "Create Demo Accounts"
4. Use the created accounts to test the app

### Method 2: Manual Script
Run the demo account creation script:
```bash
cd d:/k/Gyefo/gyefo_clocking_app
dart test_demo_accounts.dart
```

### Demo Account Credentials
- **Manager Account**: 
  - Email: `manager@test.com`
  - Password: `password123`
  - Access: Create workers, view all attendance records

- **Worker Account**: 
  - Email: `worker@test.com` 
  - Password: `password123`
  - Access: Clock in/out, view personal attendance

## Project Structure

```
lib/
├── main.dart                           # App entry point with Firebase initialization
├── models/
│   ├── user_model.dart                # User data model
│   └── attendance_model.dart          # Attendance record model
├── services/
│   ├── auth_service.dart              # Authentication operations
│   ├── firestore_service.dart         # Firestore database operations
│   └── attendance_service.dart        # Attendance-specific operations
├── screens/
│   ├── login_screen.dart              # Login interface
│   ├── loading_screen.dart            # Loading state
│   ├── manager_dashboard.dart         # Manager main screen
│   ├── worker_dashboard.dart          # Worker main screen
│   ├── manager_create_worker_screen.dart  # Create new worker accounts
│   ├── manager_attendance_screen.dart     # View worker list
│   ├── worker_attendance_detail_screen.dart  # Individual attendance records
│   └── demo_setup_screen.dart         # Demo account setup (debug only)
├── widgets/
│   └── clock_button.dart              # Clock in/out button widget
└── utils/
    └── demo_setup.dart                # Demo account creation utilities
```

## Installation & Setup

1. **Prerequisites**:
   - Flutter SDK
   - Firebase CLI
   - Firebase project with Authentication and Firestore enabled

2. **Clone and Setup**:
   ```bash
   cd d:/k/Gyefo/gyefo_clocking_app
   flutter pub get
   ```

3. **Firebase Configuration**:
   - Ensure `firebase_options.dart` is properly configured
   - Deploy Firestore rules: `firebase deploy --only firestore:rules`

4. **Run the App**:
   ```bash
   flutter run
   ```

## Usage

### For Managers
1. Login with manager credentials
2. **Create Workers**: Use "Create Worker Account" to add new employees
3. **View Attendance**: Check "Worker Attendance" to see all employee records
4. **Manage System**: Full access to all attendance data

### For Workers
1. Login with worker credentials  
2. **Clock In**: Tap the clock button to start your work day
3. **Clock Out**: Tap again to end your work day (shows hours worked)
4. **View Records**: Check your personal attendance history
5. **Date Filtering**: View attendance for specific date ranges

## Key Features

### Security
- Firestore security rules prevent unauthorized access
- Role-based authentication enforced at multiple levels
- Manager re-authentication required for creating worker accounts

### Attendance System
- One clock-in per day restriction
- Automatic hours worked calculation
- Date-based attendance filtering
- Comprehensive attendance history

### User Experience
- Clean, modern UI design
- Loading states and error handling
- Intuitive navigation between features
- Debug-only demo setup for testing

## Development Notes

- Demo account creation is only available in debug mode for security
- Uses `flutter_riverpod` for state management
- Implements proper error handling throughout the app
- Follows Flutter best practices for project structure

## Testing

Use the demo accounts to test all functionality:
1. Test manager workflows (creating workers, viewing attendance)
2. Test worker workflows (clocking in/out, viewing personal records)
3. Verify role-based access restrictions
4. Test attendance tracking accuracy
