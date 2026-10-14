# Aegymer

<p align="center">
  <img src="flutter_application_1/web/icons/Icon-192.png" alt="Aegymer Logo" width="96" height="96" />
</p>

<p align="center">
  <strong>Private, Offline-First Fitness & Nutrition Tracking App</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=Dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Desktop-blue?style=for-the-badge" alt="Platforms" />
  <img src="https://img.shields.io/badge/Database-SQLite%20(Drift)-green?style=for-the-badge" alt="SQLite" />
  <img src="https://img.shields.io/badge/Privacy-100%25%20Offline%20First-orange?style=for-the-badge" alt="Offline First" />
</p>

---

Aegymer is a modern, privacy-focused fitness and nutrition companion engineered with Flutter. Built from the ground up on an **offline-first local database (SQLite via Drift)**, Aegymer provides comprehensive workout tracking, continuous auto-save crash recovery, progressive overload analytics, and macro-based meal suggestions—without requiring personal email sign-ups or sending your health data to third-party servers.

---

## Key Features

- **🏋️‍♂️ Training & Workout Logging**
  - Track barbell lifts, dumbbells, weighted/assisted bodyweight, and cardio movements.
  - Built-in automatic rest timer, plate calculator, and accurate per-set calorie burn estimations.
  - **Crash & Exit Recovery**: Background auto-save preserves all active workout sets every 10 seconds and on app lifecycle changes. Never lose your progress if you exit on the last set.
- **📝 Complete Workout History Management**
  - Dedicated history view to browse every past training session.
  - In-place editing and deletion of past sessions, weights, and reps with instant streak and volume recalculations.
- **🥗 Nutrition & Smart Meal Planning**
  - Automated BMR & TDEE calculation based on body metrics and activity level.
  - Smart meal suggestion engine matching foods to your remaining daily calories and macronutrient ratios (Protein, Carbs, Fats).
  - Food search powered by OpenFoodFacts with customizable portion sizes.
- **📈 Analytics & Progressive Overload**
  - Volume load trends and estimated 1RM (e1RM) progression charts.
  - Muscle group distribution breakdown (Chest, Back, Legs, Shoulders, Arms, Core).
- **🔒 Privacy First & Zero Telemetry**
  - 100% local SQLite database. No mandatory account creation or cloud lock-in.
  - Full local backup export and restore via JSON.

---

## Screenshots

<p align="center">
  <img src="screenshots/homepage.gif" width="215" alt="Home page walkthrough" />
  &nbsp;&nbsp;
  <img src="screenshots/workout_session.gif" width="215" alt="Workout session logging" />
  &nbsp;&nbsp;
  <img src="screenshots/progress_chart.gif" width="215" alt="Progress & Charts" />
  &nbsp;&nbsp;
  <img src="screenshots/meal.gif" width="215" alt="Meal planning" />
</p>

<p align="center">
  <sub>Left to right: Daily Dashboard & Streak, Active Workout Logging, Progress Analytics, Smart Meal Planning.</sub>
</p>

---

## Architecture & Project Structure

The project follows a clean, modular structure separating data layers, business services, and presentation widgets:

```
flutter_application_1/
├── android/                   # Native Android configuration (release keystore, manifest)
├── lib/
│   ├── core/
│   │   ├── databases/         # Drift SQLite schema (sessions, sets, foods, routines, profiles)
│   │   ├── repositories/      # Data access layer for food, meals, user profile
│   │   ├── services/          # Core domain services (workout draft, backup, streak, nutrition)
│   │   ├── theme/             # Global light and dark design system tokens
│   │   └── utils/             # Math calculators (e1RM, calories, duration formatters)
│   ├── helper/                # First-launch detection and preference managers
│   ├── models/                # Domain data models, score results, and DTOs
│   ├── presentation/
│   │   ├── AppBars/           # Custom top app bars
│   │   ├── screen/
│   │   │   ├── Home_and_Main/ # Dashboard, streak summary, recent sessions
│   │   │   ├── MealPrep/      # Meal logging, macro counters, food search
│   │   │   ├── UserProfile/   # Body metrics, target goals, and preferences
│   │   │   └── ...            # Active workout, routine editor, workout history
│   │   └── widgets/           # Shared reusable UI components
│   └── main.dart              # Application entry point and database initialization
└── test/                      # Unit and widget tests
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `>=3.22.0`)
- [Dart SDK](https://dart.dev/get-dart) (version `^3.4.0`)
- Android Studio / VS Code with Flutter extension
- Android SDK (API level 30 or newer recommended)

### Local Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/felixilars/Aegymer.git
   cd Aegymer/flutter_application_1
   ```

2. **Install project dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate Drift Database code (if modifying schemas):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the development app:**
   ```bash
   flutter run
   ```

---

## Building Release APK

To produce a production release APK for Android devices:

```bash
cd flutter_application_1
flutter build apk --release
```

The compiled APK will be generated at:
```
flutter_application_1/build/app/outputs/flutter-apk/app-release.apk
```

> **Note on Updates**: Ensure your signing keystore (`key.properties` and `.jks`) remains consistent across builds and increment the `versionCode` in `pubspec.yaml` (e.g., `1.0.1+2`) so Android can install updates smoothly over existing installations without losing local database records.

---

## Contributing

Contributions, issues, and feature suggestions are welcome!
Feel free to open an issue or submit a pull request on [GitHub](https://github.com/felixilars/Aegymer).

---

## License

This project is licensed under the [MIT License](LICENSE).
