import 'package:drift/drift.dart';

class Routines extends Table {
  TextColumn get id => text()(); // UUID Primary Key
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
