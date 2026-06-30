import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_application_1/core/databases/user_profile.dart';
import 'package:flutter_application_1/core/databases/workout_sessions.dart';
import 'package:flutter_application_1/core/databases/workout_sets.dart';
import 'package:flutter_application_1/core/databases/user_meals.dart';
import 'package:flutter_application_1/core/databases/exercises.dart';
import 'package:flutter_application_1/core/databases/food.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UserProfiles,
    WorkoutSessions,
    WorkoutSets,
    UserMeals,
    Exercises,
    Foods,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_database',
      native: const DriftNativeOptions(
        // By default, `driftDatabase` from `package:drift_flutter` stores the
        // database files in `getApplicationDocumentsDirectory()`.
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
      // If you need web support, see https://drift.simonbinder.eu/platforms/web/
    );
  }
}
