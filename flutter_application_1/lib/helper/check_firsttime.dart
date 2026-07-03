import 'package:shared_preferences/shared_preferences.dart';

class CheckFirstTime {
  static Future<bool> isFirstTime() async {
    // Implement your logic to check if it's the first time the app is being run
    // For example, you can use SharedPreferences to store a flag
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime') ?? true;
    return isFirstTime;
  }

  static Future<void> setFirstTime(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', value);
  }
}