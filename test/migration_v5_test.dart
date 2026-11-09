import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aegymer/core/databases/app_database.dart';

/// Opens a database whose on-disk schema is the real v4 schema
/// (test/fixtures/schema_v4.sql), seeded with [seedSql], then lets the
/// current AppDatabase migrate it.
AppDatabase openV4(List<String> seedSql) {
  final ddl = File('test/fixtures/schema_v4.sql').readAsStringSync();
  return AppDatabase(NativeDatabase.memory(setup: (raw) {
    raw.execute(ddl);
    for (final stmt in seedSql) {
      raw.execute(stmt);
    }
    raw.execute('PRAGMA user_version = 4');
  }));
}

void main() {
  test('v4 -> v5 keeps history, repairs orphans and enforces foreign keys', () async {
    final db = openV4([
      "INSERT INTO exercises (id, name, target_muscle, equipment) VALUES ('bench', 'Bench Press', 'Chest', 'Barbell')",
      "INSERT INTO workout_sessions (id, date) VALUES ('s1', 1730000000)",
      // Valid set.
      "INSERT INTO workout_sets (id, session_id, exercise_id, set_number, weight, reps) VALUES ('ok', 's1', 'bench', 1, 60, 8)",
      // Exercise was deleted: must be kept, with a placeholder exercise.
      "INSERT INTO workout_sets (id, session_id, exercise_id, set_number, weight, reps) VALUES ('lost-ex', 's1', 'gone', 2, 20, 10)",
      // Session no longer exists: unreachable, removed.
      "INSERT INTO workout_sets (id, session_id, exercise_id, set_number, weight, reps) VALUES ('lost-session', 'nope', 'bench', 1, 60, 8)",
      "INSERT INTO user_meals (id, date, meal_type) VALUES ('m1', 1730000000, 'Lunch')",
      "INSERT INTO meal_items (id, meal_id, food_id, amount) VALUES ('mi1', 'm1', 'missing-food', 150)",
      "INSERT INTO meal_items (id, meal_id, food_id, amount) VALUES ('mi2', 'no-meal', 'missing-food', 50)",
    ]);
    addTearDown(db.close);

    final sets = await db.select(db.workoutSets).get();
    expect(sets.map((s) => s.id).toSet(), {'ok', 'lost-ex'});
    expect(sets.firstWhere((s) => s.id == 'ok').weight, 60);

    final placeholder = await (db.select(db.exercises)..where((t) => t.id.equals('gone'))).getSingle();
    expect(placeholder.name, 'Archived Exercise (gone)');

    final items = await db.select(db.mealItems).get();
    expect(items.map((i) => i.id), ['mi1']);
    expect(await (db.select(db.foods)..where((t) => t.id.equals('missing-food'))).get(), hasLength(1));

    final fkErrors = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fkErrors, isEmpty);

    final ddl = await db.customSelect(
        "SELECT sql FROM sqlite_master WHERE name = 'workout_sets'").getSingle();
    expect(ddl.read<String>('sql'), contains('REFERENCES exercises'));

    // New writes are now checked.
    await expectLater(
      db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
            id: 'bad', sessionId: 's1', exerciseId: 'nope', setNumber: 1, weight: 0, reps: 1)),
      throwsA(anything),
    );
  });
}
