# Fit

Fitness tracking app — pick a programme, log every set, track week over week.
Single-user, Android-first, built with Flutter.

## Build

```bash
export ANDROID_HOME=$HOME/android-sdk
flutter pub get        # Resolve packages
make build             # Debug APK → ~/Downloads/Fit.apk
make test              # Run the test suite
make run               # Build + adb install + launch
```

## Setup

1. Create a Firebase project, register `com.kingpinxd.fitcp` for Android, and
   add the release keystore SHA-1 to it.
2. Download `google-services.json` to `android/app/`.
3. Enable Google Sign-In under Firebase Authentication.

## Tech Stack

- Flutter 3.41 / Dart 3.11
- flutter_riverpod 3.x for state, drift 2.x for local SQLite
- Firebase Auth + Google Sign-In for the auth gate
- `excel` + `archive` for XLSX programme imports (hyperlinks read straight from the zip)
- Material 3 dark theme, applicationId `com.kingpinxd.fitcp`, minSdk 26 / targetSdk 34
