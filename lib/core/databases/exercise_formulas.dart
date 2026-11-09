import 'package:drift/drift.dart';

/// User-written load / calorie formulas per exercise (see ExerciseFormula).
/// Kept out of `exercises` so the catalog sync can never overwrite them.
@DataClassName('ExerciseFormulaRow')
class ExerciseFormulas extends Table {
  // Raw SQL foreign key: see the note in workout_sets.dart.
  TextColumn get exerciseId => text().customConstraint('NOT NULL REFERENCES exercises(id)')();

  TextColumn get loadFormula => text().nullable()();
  TextColumn get kcalFormula => text().nullable()();

  @override
  Set<Column> get primaryKey => {exerciseId};
}
