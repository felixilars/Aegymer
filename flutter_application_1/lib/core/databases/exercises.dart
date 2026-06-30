import 'package:drift/drift.dart';

class Exercises extends Table {
  TextColumn get id => text()(); // UUID PK

  TextColumn get name => text()();
  TextColumn get targetMuscle => text()();
  TextColumn get equipment => text()();
  TextColumn get description => text().nullable()();
  TextColumn get videoUrl => text().nullable()();

  // Is this a user-added assignment or a sample assignment synchronized from the system?
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  TextColumn get trackingType => text().nullable()();
  TextColumn get secondaryTrackingTypes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
