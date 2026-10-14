import 'package:drift/drift.dart';

class UserMeals extends Table {
  TextColumn get id => text()();

  DateTimeColumn get date => dateTime()();

  TextColumn get mealType => text()();


  @override
  Set<Column> get primaryKey => {id};
}