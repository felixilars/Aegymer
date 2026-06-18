import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:flutter_application_1/core/utils/workout_cal.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/services/backup_service.dart';

void main() {
  // ----------------------------------------------------------------------
  // 1. WorkoutCalculator Unit Tests
  // ----------------------------------------------------------------------
  group('1. WorkoutCalculator Unit Tests', () {
    test('calculateE1RM: Estimate 1 Rep Max', () {
      // 100kg x 10 rep -> 100 * (1 + 0.3333) = 133.33
      expect(WorkoutCalculator.calculateE1RM(100.0, 10), closeTo(133.33, 0.01));
      expect(WorkoutCalculator.calculateE1RM(80.0, 5), closeTo(93.33, 0.01));
      expect(WorkoutCalculator.calculateE1RM(100.0, 0), equals(0.0));
      expect(WorkoutCalculator.calculateE1RM(0.0, 10), equals(0.0));
    });

    test(
      'calculateCaloriesBurned: Calculate energy consumption based on MET',
      () {
        // 6.0 * 3.5 * 70 / 200 * 60 = 441.0 kcal
        expect(
          WorkoutCalculator.calculateCaloriesBurned(
            bodyweightKg: 70.0,
            durationMinutes: 60,
            met: 6.0,
          ),
          equals(441.0),
        );
      },
    );

    test('calculateVolume: Calculate total volume of workout session', () {
      // 2 set: set1 60kgx10reps = 600, set2 70kgx8reps = 560 -> Total = 1160
      expect(
        WorkoutCalculator.calculateVolume([60.0, 70.0], [10, 8]),
        equals(1160.0),
      );
    });

    test(
      'calculateDropOffRate: Calculate the drop-off rate of reps between sets',
      () {
        // First set 12 reps, Last set 8 reps -> (12 - 8) / 12 = 0.3333 (33.3%)
        expect(
          WorkoutCalculator.calculateDropOffRate([12, 10, 8]),
          closeTo(0.3333, 0.0001),
        );
        expect(
          WorkoutCalculator.calculateDropOffRate([10, 10, 10]),
          equals(0.0),
        );
      },
    );

    test('calculateACWR: Calculate the ratio of acute/chronic load', () {
      // Volume this session: 1200. Average 4 previous sessions: 1000. ACWR = 1.2
      expect(
        WorkoutCalculator.calculateACWR(1200.0, [
          1000.0,
          1000.0,
          1000.0,
          1000.0,
        ]),
        equals(1.2),
      );
      expect(WorkoutCalculator.calculateACWR(1000.0, []), equals(1.0));
    });
  });

  // ----------------------------------------------------------------------
  // 2. SQLite Database & BackupService Integration Tests
  // ----------------------------------------------------------------------
  group('2. SQLite Database & BackupService Integration Tests', () {
    late AppDatabase db;
    late BackupService backupService;

    setUp(() {
      // Use NativeDatabase.memory() to create a virtual database running directly in RAM,
      // helping to run tests extremely fast and automatically destroy after the test is completed without generating garbage files.
      db = AppDatabase(NativeDatabase.memory());
      backupService = BackupService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Insert personal data, Export Backup to JSON and Restore successfully',
      () async {
        // 1. Insert mock personal profile data into the local database
        final profile = UserProfile(
          id: 'user-id-123',
          gender: 'Male',
          age: 26,
          weight: 70.0,
          height: 172.0,
          activityLevel: 'Active',
          target: 'Lose Fat',
          preferences: 'Vegetarian',
        );
        await db.into(db.userProfiles).insert(profile);

        // 2. Insert 2 exercises: 1 custom exercise created by the user, 1 system exercise (Global)
        await db
            .into(db.exercises)
            .insert(
              const Exercise(
                id: 'ex-custom-01',
                name: 'My Custom Pushup',
                targetMuscle: 'Chest',
                equipment: 'Bodyweight',
                isCustom: true, // User-created data
              ),
            );

        await db
            .into(db.exercises)
            .insert(
              const Exercise(
                id: 'ex-global-02',
                name: 'Standard Bench Press',
                targetMuscle: 'Chest',
                equipment: 'Barbell',
                isCustom: false, // Sample system data (no need to backup)
              ),
            );

        // 3. Perform Backup file Export
        final jsonBackupString = await backupService.exportBackup();

        // Check the generated JSON string
        final Map<String, dynamic> decodedJson = jsonDecode(jsonBackupString);

        expect(decodedJson['profiles'][0]['id'], equals('user-id-123'));

        // Ensure only backup Custom exercises (isCustom = true), do not backup system exercises
        expect(jsonBackupString, contains('My Custom Pushup'));
        expect(jsonBackupString, isNot(contains('Standard Bench Press')));

        // 4. Assume to delete all data on the machine (Clear DB)
        await db.delete(db.userProfiles).go();
        await db.delete(db.exercises).go();

        // Ensure DB is now empty
        final emptyProfiles = await db.select(db.userProfiles).get();
        expect(emptyProfiles.isEmpty, isTrue);

        // 5. Perform data restoration from JSON string (Restore)
        await backupService.restoreBackup(jsonBackupString);

        // 6. Check the data after restoration
        final restoredProfiles = await db.select(db.userProfiles).get();
        expect(restoredProfiles.length, equals(1));
        expect(restoredProfiles.first.gender, equals('Male'));

        final restoredExercises = await db.select(db.exercises).get();
        // Only restore Custom exercises, Global exercises will be synced from Cloud later
        expect(restoredExercises.length, equals(1));
        expect(restoredExercises.first.name, equals('My Custom Pushup'));
      },
    );
  });
}
