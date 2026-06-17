import 'package:drift/drift.dart';

class UserProfiles extends Table {
  TextColumn get id => text()(); // UUID

  TextColumn get email => text().nullable()();
  TextColumn get gender => text()();
  IntColumn get age => integer().check(age.isBiggerOrEqualValue(0))();

  RealColumn get weight => real().check(weight.isBiggerOrEqualValue(0))();
  RealColumn get height => real().check(height.isBiggerOrEqualValue(0))();

  TextColumn get activityLevel => text()();
  TextColumn get target => text()();
  TextColumn get preferences => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}