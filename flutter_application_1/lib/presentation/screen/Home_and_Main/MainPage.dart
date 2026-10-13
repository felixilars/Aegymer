import 'package:flutter/material.dart';
import 'package:aegymer/presentation/AppBars/HomeAppBar.dart';
import 'package:aegymer/presentation/AppBars/RecordWorkoutAppBar.dart';
import 'package:aegymer/presentation/screen/Home_and_Main/homepage.dart';
import 'package:aegymer/presentation/screen/MealPrep/meal_prep_page.dart';
import 'package:aegymer/presentation/screen/UserProfile/profile_page.dart';
import 'package:aegymer/presentation/screen/workout_launcher_screen.dart';
import 'package:aegymer/presentation/screen/workout_progress_screen.dart';
import 'package:aegymer/core/databases/app_database.dart';

import 'package:aegymer/presentation/widgets/cloud_sync_banner.dart';
import 'package:aegymer/core/services/sync_service.dart';
import 'package:aegymer/core/services/streak_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  late final AppDatabase _db;
  late final List<Widget> _pages;
  late final List<PreferredSizeWidget> _appbars;

  @override
  void initState() {
    super.initState();

    _db = AppDatabase();

    _pages = [
      Homepage(
        db: _db,
        onRecordWorkout: () {
          setState(() {
            _selectedIndex = 2;
          });
        },
      ),
      MealPrepPage(db: _db),
      WorkoutLauncherScreen(db: _db),
      WorkoutProgressScreen(db: _db),
    ];

    _appbars = [
      HomeAppBar(onProfilePressed: _openProfile),
      const PreferredSize(preferredSize: Size.zero, child: SizedBox.shrink()),
      RecordWorkoutAppBar(onHomePressed: () => setState(() => _selectedIndex = 0)),
      const PreferredSize(preferredSize: Size.zero, child: SizedBox.shrink()),
    ];
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilePage(db: _db)),
    );
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAppBar = _appbars[_selectedIndex];
    final hasAppBar = currentAppBar.preferredSize.height > 0;

    return Scaffold(
      appBar: hasAppBar ? currentAppBar : null,
      body: Column(
        children: [
          CloudSyncBanner(syncService: SyncService(_db)),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            StreakService.notifyWorkoutUpdated();
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: "Home"),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: "Meals",
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: "Process",
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: "Progress",
          ),
        ],
      ),
    );
  }
}
