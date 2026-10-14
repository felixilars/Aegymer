import 'package:shared_preferences/shared_preferences.dart';
import 'package:aegymer/core/databases/app_database.dart';

class CheckFirstTime {
  static Future<bool> isFirstTime([AppDatabase? db]) async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTimePref = prefs.getBool('isFirstTime');
    if (isFirstTimePref != null) {
      return isFirstTimePref;
    }
    // If flag is missing on update, check if user data already exists in database
    if (db != null) {
      try {
        final profiles = await db.select(db.userProfiles).get();
        if (profiles.isNotEmpty) {
          await prefs.setBool('isFirstTime', false);
          return false;
        }
      } catch (_) {}
    }
    return true;
  }

  static Future<void> setFirstTime(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', value);
  }
}