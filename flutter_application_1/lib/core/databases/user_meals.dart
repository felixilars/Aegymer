import 'package:drift/drift.dart';

class UserMeals extends Table {
  TextColumn get id => text()();

  DateTimeColumn get date => dateTime()();

  TextColumn get mealType => text()();

  TextColumn get items => text()();

  RealColumn get totalCalories => real()();

  @override
  Set<Column> get primaryKey => {id};
}