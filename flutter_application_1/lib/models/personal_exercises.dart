import 'package:drift/drift.dart';

class PersonalExercises extends Table {
  TextColumn get id => text()(); // UUID

  TextColumn get name => text()();
  TextColumn get target_muscle => text()();
  TextColumn get equipment => text().nullable()();
  TextColumn get description => text().nullable()();
  
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}




