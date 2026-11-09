import 'package:drift/drift.dart';

class WorkoutSets extends Table {
  TextColumn get id => text()();

  // Foreign keys are written as raw SQL: the pinned drift_dev/analyzer cannot
  // resolve `.references(Table, #col)` with the current Dart SDK and silently
  // drops the constraint. Enforced via `PRAGMA foreign_keys = ON` (AppDatabase).
  TextColumn get sessionId =>
      text().customConstraint('NOT NULL REFERENCES workout_sessions(id)')();
  TextColumn get exerciseId =>
      text().customConstraint('NOT NULL REFERENCES exercises(id)')();

  IntColumn get setNumber => integer().customConstraint('NOT NULL CHECK (set_number >= 0)')();
  RealColumn get weight => real().customConstraint('NOT NULL CHECK (weight >= 0)')();
  IntColumn get reps => integer().customConstraint('NOT NULL CHECK (reps >= 0)')();

  IntColumn get rpe => integer().nullable()();
  RealColumn get calculated1rm => real().nullable()();

  TextColumn get weightType => text().nullable()();
  RealColumn get distance => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  // Results of the exercise's custom formula at save time (null = no custom
  // formula: use `weight` and the built-in calorie estimate). Stored so that
  // editing a formula doesn't silently rewrite history.
  RealColumn get effectiveLoad => real().nullable()();
  RealColumn get calories => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}