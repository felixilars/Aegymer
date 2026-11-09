import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/backup_file_gateway.dart';
import 'package:aegymer/core/services/backup_service.dart';
import 'package:aegymer/presentation/screen/settings_page.dart';

/// In-memory stand-in for the system save/open dialogs.
class FakeBackupFiles extends BackupFileGateway {
  String? savedName;
  Uint8List? savedBytes;
  Uint8List? toPick;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    savedName = fileName;
    savedBytes = bytes;
    return true;
  }

  @override
  Future<Uint8List?> pick() async => toPick;
}

Future<void> seed(AppDatabase db) async {
  await db.into(db.exercises).insert(ExercisesCompanion.insert(
      id: 'bench', name: 'Bench Press', targetMuscle: 'Chest', equipment: 'Barbell'));
  await db.saveWorkoutSession(
    sessionId: 's1',
    date: DateTime(2026, 11, 1),
    setsCompanions: [
      WorkoutSetsCompanion.insert(
          id: 'set1', sessionId: 's1', exerciseId: 'bench', setNumber: 1, weight: 80, reps: 5),
    ],
  );
}

void main() {
  group('BackupService.inspect', () {
    test('summarizes a real backup', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);
      final summary = BackupService.inspect(await BackupService(db).exportBackup());
      expect(summary.version, BackupService.currentVersion);
      expect(summary.sessions, 1);
      expect(summary.sets, 1);
      expect(summary.createdAt, isNotNull);
    });

    test('rejects files that are not backups', () {
      expect(() => BackupService.inspect('not json'), throwsFormatException);
      expect(() => BackupService.inspect('{"foo": 1}'), throwsFormatException);
      expect(() => BackupService.inspect('[1, 2]'), throwsFormatException);
    });

    test('rejects backups from a newer app version', () {
      final newer = jsonEncode({'version': 99, 'backup_timestamp': '2026-11-09T00:00:00'});
      expect(() => BackupService.inspect(newer), throwsFormatException);
    });
  });

  group('Settings backup UI', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> openSettings(WidgetTester tester, AppDatabase db, FakeBackupFiles files) async {
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: SettingsPage(db: db, backupFiles: files)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Backup & Restore'), 300);
    }

    Future<void> tapButton(WidgetTester tester, String label) async {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
    }

    testWidgets('export on one device, restore on another', (tester) async {
      final phoneA = AppDatabase(NativeDatabase.memory());
      final phoneB = AppDatabase(NativeDatabase.memory());
      addTearDown(phoneA.close);
      addTearDown(phoneB.close);
      await tester.runAsync(() => seed(phoneA));

      final files = FakeBackupFiles();
      await openSettings(tester, phoneA, files);
      await tapButton(tester, 'Export');
      await settle(tester);

      expect(files.savedName, matches(RegExp(r'^aegymer-backup-\d{4}-\d{2}-\d{2}\.json$')));
      expect(find.text('Backup saved.'), findsOneWidget);

      files.toPick = files.savedBytes;
      await openSettings(tester, phoneB, files);
      await tapButton(tester, 'Restore');
      await settle(tester);

      expect(find.text('Restore this backup?'), findsOneWidget);
      expect(find.text('• 1 workouts (1 sets)'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await settle(tester);

      final sets = await tester.runAsync(() => phoneB.select(phoneB.workoutSets).get());
      expect(sets!.single.weight, 80);
      expect(find.textContaining('Restored 1 workouts'), findsOneWidget);
    });

    testWidgets('picking a wrong file shows an error and changes nothing', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final files = FakeBackupFiles()..toPick = utf8.encode('{"hello": "world"}');

      await openSettings(tester, db, files);
      await tapButton(tester, 'Restore');
      await settle(tester);

      expect(find.text('This file is not an Aegymer backup.'), findsOneWidget);
      expect(find.text('Restore this backup?'), findsNothing);
    });
  });
}
