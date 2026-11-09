import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aegymer/core/databases/app_database.dart';

/// Opens a database with the real v5 schema (dumped from a device in
/// test/fixtures/schema_v5.sql), seeded with [seedSql].
AppDatabase openVersion(String fixture, int version, List<String> seedSql) {
  final ddl = File(fixture).readAsStringSync();
  return AppDatabase(NativeDatabase.memory(setup: (raw) {
    raw.execute(ddl);
    for (final stmt in seedSql) {
      raw.execute(stmt);
    }
    raw.execute('PRAGMA user_version = $version');
  }));
}

const _seed = [
  "INSERT INTO exercises (id, name, target_muscle, equipment, is_custom) VALUES ('lp', 'Leg Press', 'Legs', 'Machine', 0)",
  "INSERT INTO workout_sessions (id, date) VALUES ('s1', 1790000000)",
  "INSERT INTO workout_sets (id, session_id, exercise_id, set_number, weight, reps, calculated1rm, weight_type, duration_seconds) "
      "VALUES ('set1', 's1', 'lp', 1, 200, 10, 266.7, 'standard', 90)",
];

void main() {
  for (final (fixture, version) in [
    ('test/fixtures/schema_v5.sql', 5),
    ('test/fixtures/schema_v4.sql', 4),
  ]) {
    test('v$version -> v6 keeps sets and adds the formula columns', () async {
      final db = openVersion(fixture, version, _seed);
      addTearDown(db.close);

      final set = await db.select(db.workoutSets).getSingle();
      expect(set.weight, 200);
      expect(set.reps, 10);
      expect(set.calculated1rm, closeTo(266.7, 0.01));
      expect(set.weightType, 'standard');
      expect(set.durationSeconds, 90);
      expect(set.effectiveLoad, isNull);
      expect(set.calories, isNull);

      await db.saveExerciseFormula('lp', load: 'weight * 0.5');
      expect((await db.getExerciseFormula('lp'))?.loadFormula, 'weight * 0.5');
      expect(await db.recomputeFormulaHistory('lp'), 1);
      expect((await db.select(db.workoutSets).getSingle()).effectiveLoad, 100);
    });
  }
}
