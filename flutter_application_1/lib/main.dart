import 'package:flutter/material.dart';
import 'package:aegymer/presentation/screen/Home_and_Main/MainPage.dart';
import 'package:aegymer/core/services/sync_service.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/helper/check_firsttime.dart';
import 'package:aegymer/core/theme/app_theme.dart';
import 'package:aegymer/presentation/screen/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firstTimeFuture = CheckFirstTime.isFirstTime();
  final db = AppDatabase();
  unawaited(SyncService(db).initializeAndSync());

  final isFirstTime = await firstTimeFuture;
  runApp(MyApp(isFirstTime: isFirstTime));
}

void unawaited(Future<void>? future) {}

class MyApp extends StatelessWidget {
  final bool isFirstTime;

  const MyApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegymer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: isFirstTime ? const WelcomeScreen() : const MainPage(),
    );
  }
}
