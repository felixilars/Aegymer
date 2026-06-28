import 'package:flutter/material.dart';
import 'package:flutter_application_1/helper/check_firsttime.dart';
import 'package:flutter_application_1/presentation/screen/workout_log_screen.dart';
import 'package:flutter_application_1/presentation/welcome_page.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Icon(
                Icons.fitness_center,
                size: 100,
                color: Color.fromARGB(255, 105, 30, 49),
              ),

              const SizedBox(height: 40),

              const Text(
                "Welcome to Aegyme!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Track your workouts, your meals, monitor your progress, and achieve your fitness goals with ease.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color.fromARGB(255, 94, 31, 31),
                ),
              ),

              const SizedBox(height: 60),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    await CheckFirstTime.setFirstTime(false);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkoutLogScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Get Started",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}