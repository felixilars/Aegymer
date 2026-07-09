import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/presentation/screen/Home_and_Main/MainPage.dart';
import 'package:flutter_application_1/presentation/screen/welcome_screen.dart';
import 'package:flutter_application_1/presentation/screen/workout_log_screen.dart';
import 'package:flutter_application_1/presentation/screen/Home_and_Main/MainPage.dart';


import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/services/backup_service.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/helper/check_firsttime.dart';


import 'package:drift/drift.dart' hide Column;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //CheckFirstTime.setFirstTime(true); // Reset first-time flag for testing 

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]); // Lock the app to portrait mode

  runApp(const MyApp());
}

// Helper function to automatically insert sample data into Supabase Cloud if table is empty
Future<void> seedSupabaseCloud() async {
  final supabase = Supabase.instance.client;
  try {
    final existingExercises = await supabase
        .from('global_exercises')
        .select('id')
        
        .limit(1);
    if (existingExercises.isEmpty) {
      print(
        "Supabase Cloud 'global_exercises' đang trống. Tiến hành seed dữ liệu mẫu...",
      );
      await supabase.from('global_exercises').insert([
        {
          'name': 'Bench Press',
          'target_muscle': 'Chest',
          'equipment': 'Barbell',
          'description': 'Flat barbell bench press.',
        },
        {
          'name': 'Squat',
          'target_muscle': 'Quads',
          'equipment': 'Barbell',
          'description': 'Barbell back squat.',
        },
        {
          'name': 'Deadlift',
          'target_muscle': 'Hamstrings',
          'equipment': 'Barbell',
          'description': 'Conventional barbell deadlift.',
        },
      ]);
      print("Sample exercises seeded to Supabase!");
    }
    final existingFoods = await supabase
        .from('global_foods')
        .select('id')
        .limit(1);
    if (existingFoods.isEmpty) {
      print(
        "Supabase Cloud 'global_foods' is empty. Proceeding to seed sample foods...",
      );
      await supabase.from('global_foods').insert([
        {
          'name': 'Chicken Breast (Raw, 100g)',
          'calories': 120.0,
          'protein': 26.0,
          'carbs': 0.0,
          'fat': 1.5,
          'category': 'Protein',
        },
        {
          'name': 'White Rice (Cooked, 100g)',
          'calories': 130.0,
          'protein': 2.7,
          'carbs': 28.0,
          'fat': 0.3,
          'category': 'Carbs',
        },
      ]);
      print("Sample foods seeded to Supabase!");
    }
  } catch (e) {
    print(
      "Error seeding Supabase: $e (Maybe tables are not created or RLS policy on Supabase is blocking)",
    );
  }
}

// Test function for local SQLite and Backup Service
Future<void> runLocalDatabaseAndBackupTests(AppDatabase db) async {
  print("\n--- TEST LOCAL DATABASE SYSTEM ---");

  // Check if there is already a profile, if not, insert a test one
  final profiles = await db.select(db.userProfiles).get();
  if (profiles.isEmpty) {
    print("Local Database SQLite is empty, inserting sample personal data...");

    // 1. Insert Profile
    await db
        .into(db.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: 'my-user-001',
            gender: 'Female',
            age: 24,
            weight: 55.0,
            height: 162.0,
            activityLevel: 1.725,
            target: 'Lose Fat',
            preferences: const Value('No Seafood'),
          ),
        );
    // 2. Insert a custom exercise created by the user
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'my-custom-ex-001',
            name: 'Incline Pushup (Bench/Chair)',
            targetMuscle: 'Chest',
            equipment: 'Bench',
            isCustom: const Value(true), // isCustom = true
          ),
        );
    print("Sample personal data inserted successfully!");
  }
  // Read data again to print to console
  final currentProfiles = await db.select(db.userProfiles).get();
  final currentExercises = await db.select(db.exercises).get();

  print("\n=== LOCAL SQLite DATA INFORMATION ===");
  print(
    "Current profile: ${currentProfiles.first.gender}, Weight: ${currentProfiles.first.weight} kg, Target: ${currentProfiles.first.target}",
  );
  print("Total local exercises: ${currentExercises.length}");
  for (var ex in currentExercises) {
    print("  - ${ex.name} (Custom: ${ex.isCustom})");
  }
  // 3. Run test export Backup JSON
  print("\n=== RUN TEST EXPORT BACKUP JSON ===");
  final backupService = BackupService(db);
  final backupJson = await backupService.exportBackup();
  print("Backup JSON file generated:\n$backupJson");

  print("--- END LOCAL DATABASE SYSTEM TEST ---\n");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: FutureBuilder<bool>(
        future: CheckFirstTime.isFirstTime(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const WelcomeScreen();
          }
          return const MainPage();
        },
      ),
    );
  }
}


