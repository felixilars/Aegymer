import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyThemeMode = 'app_setting_theme_mode';
  static const String keyWeightAutofill = 'app_setting_weight_autofill_mode';
  static const String keyDefaultBarbellWeight = 'app_setting_default_barbell_weight';
  static const String keyAutoRestTimer = 'app_setting_auto_rest_timer';

  /// Notifiers for real-time reactivity without external state management packages
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final ValueNotifier<String> weightAutofillNotifier = ValueNotifier<String>('historical');
  static final ValueNotifier<double> defaultBarbellWeightNotifier = ValueNotifier<double>(20.0);
  static final ValueNotifier<bool> autoRestTimerNotifier = ValueNotifier<bool>(true);

  static SharedPreferences? _prefs;

  /// Initialize and load saved settings from SharedPreferences
  static Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      // 1. Theme Mode
      final themeStr = _prefs?.getString(keyThemeMode) ?? 'system';
      if (themeStr == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else if (themeStr == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else {
        themeModeNotifier.value = ThemeMode.system;
      }

      // 2. Weight Autofill Mode: 'historical' (last workout) vs 'default' (app default 40kg)
      final autofillStr = _prefs?.getString(keyWeightAutofill) ?? 'historical';
      weightAutofillNotifier.value = autofillStr;

      // 3. Default Barbell Weight
      final barW = _prefs?.getDouble(keyDefaultBarbellWeight) ?? 20.0;
      defaultBarbellWeightNotifier.value = barW;

      // 4. Auto Rest Timer
      final restTimer = _prefs?.getBool(keyAutoRestTimer) ?? true;
      autoRestTimerNotifier.value = restTimer;
    } catch (e) {
      debugPrint('Error initializing SettingsService: $e');
    }
  }

  // --- Theme Mode ---
  static ThemeMode get themeMode => themeModeNotifier.value;

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    _prefs ??= await SharedPreferences.getInstance();
    String val = 'system';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    await _prefs?.setString(keyThemeMode, val);
  }

  // --- Weight Autofill Mode ---
  static String get weightAutofillMode => weightAutofillNotifier.value;

  static Future<void> setWeightAutofillMode(String mode) async {
    weightAutofillNotifier.value = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(keyWeightAutofill, mode);
  }

  // --- Default Barbell Weight ---
  static double get defaultBarbellWeight => defaultBarbellWeightNotifier.value;

  static Future<void> setDefaultBarbellWeight(double weight) async {
    defaultBarbellWeightNotifier.value = weight;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setDouble(keyDefaultBarbellWeight, weight);
  }

  // --- Auto Rest Timer ---
  static bool get autoRestTimer => autoRestTimerNotifier.value;

  static Future<void> setAutoRestTimer(bool enabled) async {
    autoRestTimerNotifier.value = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(keyAutoRestTimer, enabled);
  }

  // --- Reset All Preferences ---
  static Future<void> resetAllSettings() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(keyThemeMode);
    await _prefs?.remove(keyWeightAutofill);
    await _prefs?.remove(keyDefaultBarbellWeight);
    await _prefs?.remove(keyAutoRestTimer);

    themeModeNotifier.value = ThemeMode.system;
    weightAutofillNotifier.value = 'historical';
    defaultBarbellWeightNotifier.value = 20.0;
    autoRestTimerNotifier.value = true;
  }
}
