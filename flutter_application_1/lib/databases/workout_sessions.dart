import 'package:drift/drift.dart';

class WorkoutSessions extends Table {
  TextColumn get id => text()();

  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}