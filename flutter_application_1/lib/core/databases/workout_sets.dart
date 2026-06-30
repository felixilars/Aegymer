import 'package:drift/drift.dart';
import 'package:flutter_application_1/core/databases/exercises.dart';
import 'package:flutter_application_1/core/databases/workout_sessions.dart';



class WorkoutSets extends Table {
  TextColumn get id => text()();

  TextColumn get sessionId => text().references(WorkoutSessions, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();

  IntColumn get setNumber => integer().check(setNumber.isBiggerOrEqualValue(0))();
  RealColumn get weight => real().check(weight.isBiggerOrEqualValue(0))();
  IntColumn get reps => integer().check(reps.isBiggerOrEqualValue(0))();

  IntColumn get rpe => integer().nullable()();
  RealColumn get calculated1rm => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}