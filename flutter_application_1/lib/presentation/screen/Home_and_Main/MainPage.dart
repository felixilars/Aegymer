import 'package:flutter/material.dart';
import 'package:flutter_application_1/presentation/AppBars/HomeAppBar.dart';
import 'package:flutter_application_1/presentation/AppBars/RecordWorkoutAppBar.dart';
import 'package:flutter_application_1/presentation/screen/Home_and_Main/homepage.dart';
import 'package:flutter_application_1/presentation/screen/MealPrep/meal_prep_page.dart';
import 'package:flutter_application_1/presentation/screen/UserProfile/profile_page.dart';
import 'package:flutter_application_1/presentation/screen/workout_launcher_screen.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';










class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  late final AppDatabase _db;
  late final List<Widget> _pages;
  late final List<Widget> _appbars;

  @override
  void initState() {
    super.initState();

    _db = AppDatabase();

    _pages = [
      Homepage(onRecordWorkout: () {
        setState(() {
          _selectedIndex = 2;
        });
      }),
      const MealPrepPage(),
      WorkoutLauncherScreen(db: _db),
      const ProfilePage(),
    ];

    _appbars = [
      const HomeAppBar(),
      const HomeAppBar(),
      const RecordWorkoutAppBar(),
      const HomeAppBar(),
    ];
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appbars[_selectedIndex] as PreferredSizeWidget,
      body: _pages[_selectedIndex], 
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index; 
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: "Homehahahaha",
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: "Meals",
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: "Workout",
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}