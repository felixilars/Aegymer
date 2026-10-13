import 'package:flutter/material.dart';
import 'package:aegymer/presentation/screen/Home_and_Main/MainPage.dart';
import 'package:aegymer/core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/helper/check_firsttime.dart';
import 'package:aegymer/core/theme/app_theme.dart';
import 'package:aegymer/presentation/screen/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isSupabaseReady = false;
  try {
    await Supabase.initialize(
      url: 'https://faegwvospgqmsurjpbvo.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhZWd3dm9zcGdxbXN1cmpwYnZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1ODk5MTIsImV4cCI6MjA5NzE2NTkxMn0.gLY0YRlHwNwLOCLEI8Ob-hxtMcT7EtBhXCQQBJQytls',
    );
    isSupabaseReady = true;
  } catch (e) {
    debugPrint('Supabase initialization failed or device is offline: $e');
    isSupabaseReady = false;
  }

  final db = AppDatabase();
  final syncService = SyncService(db, isSupabaseConfigured: isSupabaseReady);

  // Initialize offline seed fallback and attempt cloud sync in background
  unawaited(syncService.initializeAndSync());

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


