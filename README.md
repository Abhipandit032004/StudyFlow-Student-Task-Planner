# StudyFlow — Student Task Planner

StudyFlow is a responsive Flutter student planner with email/password authentication, per-user cloud task storage, task management, insights, a reminder center, and an animated login experience.

## Implemented in this version

- Responsive login and registration UI with animated study illustration.
- Firebase Authentication for email/password sign-up, sign-in, sign-out, and password reset.
- User profile document in Cloud Firestore.
- Tasks stored under `users/{uid}/tasks/{taskId}` so each signed-in user has a separate history.
- Create, edit, complete, and delete tasks; search and filters; schedule and insights.
- Reminder center for overdue, due-today, and due-tomorrow tasks; a reminder summary is shown when the app opens if tasks are due today or overdue.
- Mobile layout: the New Task action is in the top bar instead of floating over the bottom navigation. Tasks, Calendar, and Insights have separate navigation destinations.
- Animated loading indicator while authentication/session state is resolving and while sign-in/registration is in progress.

## Important: connect your own Firebase project first

Firebase configuration is intentionally not included in this ZIP. You must connect a Firebase project before real authentication and cloud storage will work.

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. In **Authentication → Sign-in method**, enable **Email/Password**.
3. Create a **Cloud Firestore** database.
4. Install/configure FlutterFire from the project root (the folder containing `pubspec.yaml`):

   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Select the Firebase project and platforms you intend to support. FlutterFire generates `lib/firebase_options.dart`, replacing the placeholder template in this project.
5. Apply the Firestore rules below in **Firestore Database → Rules** and publish them.
6. Run:

   ```powershell
   flutter pub get
   flutter run -d chrome
   ```

   For Android, connect a device or start an emulator and run `flutter run`.

## Firestore security rules starter

These rules ensure an authenticated user can access only their own profile and task subcollection. Review and test them before a public launch.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, create, update, delete: if request.auth != null
        && request.auth.uid == userId;
      match /tasks/{taskId} {
        allow read, create, update, delete: if request.auth != null
          && request.auth.uid == userId;
      }
    }
  }
}
```

Do not use open/public Firestore rules for a client deployment.

## Reminder behavior and production notifications

The current app includes an in-app reminder center and a reminder summary when the app opens. It does **not** yet send background push notifications or email reminders while the app is closed. Those require additional production setup: Firebase Cloud Messaging device-token handling and a trusted server-side scheduler (for example, Cloud Functions with scheduled jobs) to evaluate due tasks and send notifications. Never put server credentials in Flutter client code.

## Before handing this to a client

- Connect and test your Firebase project on every target platform.
- Verify the Firestore rules with two separate test accounts.
- Add automated tests, accessibility checks, and error/crash reporting.
- Decide the reminder policy/time zone and implement server-side scheduled push/email delivery if required.
- Configure Android app signing and release builds; configure web hosting/domain and privacy/terms pages if publishing publicly.
- Review privacy requirements and explain what student data is stored and how it is deleted.

This is a client-oriented implementation scaffold, not a claim that Firebase has already been provisioned or that background notifications are live. The Firebase setup steps above are required before handing it to a real client.
