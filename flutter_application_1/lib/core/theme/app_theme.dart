import 'package:flutter/material.dart';

/// Centralized, developer-customizable theme configuration for Aegymer.
///
/// To customize the app's look and feel, edit the primary/accent seeds
/// or background color values below.
class AppTheme {
  // Primary Palette Seeds (Easily customizable by developers)
  static const Color primarySeed = Color(0xff2563EB); // Royal Blue
  static const Color accentColor = Color(0xffFF6B35); // Energetic Coral

  // Light Theme Colors
  static const Color lightBackground = Color(0xffF5F7FA);
  static const Color lightCard = Colors.white;
  static const Color lightText = Color(0xff1F2937);
  static const Color lightSubtitle = Color(0xff6B7280);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xff121212);
  static const Color darkCard = Color(0xff1E1E1E);
  static const Color darkText = Color(0xffF9FAFB);
  static const Color darkSubtitle = Color(0xff9CA3AF);

  /// Light ThemeData
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeed,
        brightness: Brightness.light,
        surface: lightBackground,
        onSurface: lightText,
      ),
      scaffoldBackgroundColor: lightBackground,
      cardColor: lightCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightText),
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Dark ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySeed,
        brightness: Brightness.dark,
        surface: darkBackground,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
