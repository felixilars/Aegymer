import 'package:drift/drift.dart';

class MealItems extends Table {
  TextColumn get id => text()();

  // Raw-SQL foreign keys; see the note in workout_sets.dart.
  TextColumn get mealId =>
      text().customConstraint('NOT NULL REFERENCES user_meals(id)')();

  TextColumn get foodId =>
      text().customConstraint('NOT NULL REFERENCES foods(id)')();

  RealColumn get amount => real()(); // grams

  @override
  Set<Column> get primaryKey => {id};
}