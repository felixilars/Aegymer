import 'package:drift/drift.dart';

class UserProfiles extends Table {
  TextColumn get id => text()(); // UUID

  TextColumn get email => text().nullable()();
  TextColumn get gender => text()();
  IntColumn get age => integer().customConstraint('NOT NULL CHECK (age >= 0)')();

  RealColumn get weight => real().customConstraint('NOT NULL CHECK (weight >= 0)')();
  RealColumn get height => real().customConstraint('NOT NULL CHECK (height >= 0)')();

  RealColumn get activityLevel => real()();
  TextColumn get target => text()();
  TextColumn get preferences => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}