import 'package:flutter/material.dart';
import 'package:flutter_application_1/presentation/screen/workout_log_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/services/sync_service.dart';
import 'package:flutter_application_1/core/services/backup_service.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:drift/drift.dart' hide Column;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://faegwvospgqmsurjpbvo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhZWd3dm9zcGdxbXN1cmpwYnZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1ODk5MTIsImV4cCI6MjA5NzE2NTkxMn0.gLY0YRlHwNwLOCLEI8Ob-hxtMcT7EtBhXCQQBJQytls',
  );

  final db = AppDatabase();
  final syncService = SyncService(db);

  // Run Seed sample data to Supabase Cloud if empty
  await seedSupabaseCloud();
  // Proceed to sync data from Cloud to Local
  print("\n--- START SYNCING DATA FROM SUPABASE ---");
  await syncService.syncExercisesFromCloud();
  await syncService.syncFoodsFromCloud();
  // Read data local after sync
  final localExercises = await db.select(db.exercises).get();
  print("Number of exercises synced to SQLite: ${localExercises.length}");
  for (var ex in localExercises) {
    print(
      "Exercise from Cloud: ${ex.name} (Muscle: ${ex.targetMuscle}) - Custom: ${ex.isCustom}",
    );
  }
  // Run tests for Database Local and Backup/Restore
  await runLocalDatabaseAndBackupTests(db);

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
            activityLevel: 'Active',
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
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const WorkoutLogScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
