import 'package:drift/drift.dart';
import 'package:aegymer/core/databases/user_meals.dart';
import 'package:aegymer/core/databases/food.dart';

class MealItems extends Table {
  TextColumn get id => text()();

  TextColumn get mealId =>
      text().references(UserMeals, #id)();

  TextColumn get foodId =>
      text().references(Foods, #id)();

  RealColumn get amount => real()(); // grams

  @override
  Set<Column> get primaryKey => {id};
}