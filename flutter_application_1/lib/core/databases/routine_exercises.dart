import 'package:drift/drift.dart';

class RoutineExercises extends Table {
  TextColumn get id => text()(); // UUID Primary Key
  TextColumn get routineId => text()(); // Link to Routines
  TextColumn get exerciseId => text()(); // Link to Exercises
  IntColumn get orderIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
