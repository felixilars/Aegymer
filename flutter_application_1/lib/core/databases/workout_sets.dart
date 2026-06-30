import 'package:drift/drift.dart';
import 'package:flutter_application_1/core/databases/exercises.dart';


class WorkoutSets extends Table {
  TextColumn get id => text()();

  TextColumn get sessionId => text()();
  TextColumn get exerciseId => text().references(Exercises, #id)();

  IntColumn get setNumber => integer().customConstraint('NOT NULL CHECK (set_number >= 0)')();
  RealColumn get weight => real().customConstraint('NOT NULL CHECK (weight >= 0)')();
  IntColumn get reps => integer().customConstraint('NOT NULL CHECK (reps >= 0)')();

  IntColumn get rpe => integer().nullable()();
  RealColumn get calculated1rm => real().nullable()();

  TextColumn get weightType => text().nullable()();
  RealColumn get distance => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}