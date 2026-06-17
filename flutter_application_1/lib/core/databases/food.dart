import 'package:drift/drift.dart';

class Foods extends Table {
  TextColumn get id => text()(); // UUID PK

  TextColumn get name => text()();
  RealColumn get calories => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  TextColumn get category => text().nullable()();

  // Is this a user-added food or a sample food synchronized from the system?
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
