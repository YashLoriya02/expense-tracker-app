# Expense Tracker AI

A Flutter-based personal finance app to track expenses, income, budgets, accounts, and AI-powered financial insights.

## Features

- Add income, expenses, and transfers
- View monthly income, expenses, and net savings
- Budget tracking with usage progress
- Transaction history by day, week, month, year, or custom date range
- Search transactions by title, note, type, or amount
- AI-powered spending insights using Gemini
- Daily AI insight cache to reduce API usage
- Receipt scanning with OCR
- Speech-to-text for adding transactions
- Biometric app lock
- Excel export
- Dark/Light theme UI

## Tech Stack

- Flutter
- Dart
- Riverpod
- Drift / SQLite
- Gemini API
- ML Kit OCR

## Project Setup

```bash
flutter pub get
flutter run
````

### Biometric Setup

Update:

```txt
android/app/src/main/kotlin/.../MainActivity.kt
```

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity()
```

### Gemini API

Add your Gemini API key from the app settings screen to enable AI features.

AI insights are generated once per day and saved locally to reduce API calls.

## Build APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Notes

* Restore backup is currently disabled.
* AI insights use cached daily results.
* Speech-to-text uses the device speech recognizer.
* Excel export generates a local XLSX file that can be shared.

## App Goal

To provide a simple, fast, and smart expense tracking experience with helpful AI insights while keeping API usage and cost low.
