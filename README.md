# checkops_frondend

A new Flutter project.

## Android Firebase Push Setup

1. Create an Android app in Firebase with package name
   `com.example.checkops_frondend`.
2. Download `google-services.json` and place it at
   `android/app/google-services.json`.
3. Download a Firebase service-account JSON for the same Firebase project and
   store it on the backend host outside source control. Set one of these backend
   environment variables to its absolute path:
   ```env
   FIREBASE_SERVICE_ACCOUNT_PATH=/secure/path/firebase-service-account.json
   # Or use Google's standard variable:
   # GOOGLE_APPLICATION_CREDENTIALS=/secure/path/firebase-service-account.json
   ```
   Never commit either Firebase JSON file.
4. Apply the backend migration that creates `push_devices`, then run:
   ```bash
   flutter pub get
   flutter run
   ```
5. Log in and allow notification permission. The app registers its FCM token
   with the CheckOps backend automatically.

Foreground messages are displayed through `flutter_local_notifications`.
Background and terminated-app messages are displayed by Android through FCM.
Tapping a task push opens its related task entry after authentication.
iOS push initialization is intentionally left as a placeholder until APNs and
Apple Developer signing are configured.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
