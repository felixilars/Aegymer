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
  final List<Widget?> _tabPages = [null, null, null, null];
  late final List<PreferredSizeWidget> _appbars;

  @override
  void initState() {
    super.initState();

    _db = AppDatabase();

    _appbars = [
      HomeAppBar(onProfilePressed: _openProfile),
      const PreferredSize(preferredSize: Size.zero, child: SizedBox.shrink()),
      RecordWorkoutAppBar(onHomePressed: () => setState(() => _selectedIndex = 0)),
      const PreferredSize(preferredSize: Size.zero, child: SizedBox.shrink()),
    ];
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return Homepage(
          db: _db,
          onRecordWorkout: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
        );
      case 1:
        return MealPrepPage(db: _db);
      case 2:
        return WorkoutLauncherScreen(db: _db);
      case 3:
        return WorkoutProgressScreen(db: _db);
      default:
        return const SizedBox.shrink();
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilePage(db: _db)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _tabPages[_selectedIndex] ??= _buildTab(_selectedIndex);

    final currentAppBar = _appbars[_selectedIndex];
    final hasAppBar = currentAppBar.preferredSize.height > 0;

    return Scaffold(
      appBar: hasAppBar ? currentAppBar : null,
      body: Column(
        children: [
          CloudSyncBanner(syncService: SyncService(_db)),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: List.generate(
                4,
                (i) => _tabPages[i] ?? const SizedBox.shrink(),
              ),
            ),
          ),
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
