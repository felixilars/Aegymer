import 'package:flutter/material.dart';
import 'package:flutter_application_1/presentation/screen/Home_and_Main/MainPage.dart';
import 'package:flutter_application_1/core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/helper/check_firsttime.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/presentation/screen/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CheckFirstTime.setFirstTime(true); // Set the first time flag to true for testing purposes
  await Supabase.initialize(
    url: 'https://faegwvospgqmsurjpbvo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhZWd3dm9zcGdxbXN1cmpwYnZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1ODk5MTIsImV4cCI6MjA5NzE2NTkxMn0.gLY0YRlHwNwLOCLEI8Ob-hxtMcT7EtBhXCQQBJQytls',
  );

  final db = AppDatabase();
  final syncService = SyncService(db);

  // Sync data asynchronously in background without blocking UI startup
  unawaited(syncService.syncExercisesFromCloud());
  unawaited(syncService.syncFoodsFromCloud());

  runApp(const MyApp());
}

void unawaited(Future<void>? future) {}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegymer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      home: FutureBuilder<bool>(
        future: CheckFirstTime.isFirstTime(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final isFirstTime = snapshot.data!;

          if (isFirstTime) {
            return const WelcomeScreen();
          }

          return const MainPage();
        },
      ),
    );
  }
}


