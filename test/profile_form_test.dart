import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/presentation/welcome_page.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Finder submitButton() => find.text('Complete Setup & Start');

  Finder fieldWithLabel(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextFormField),
      );

  Future<void> selectDropdown(
    WidgetTester tester,
    int index,
    String option,
  ) async {
    final dropdown = find.byType(DropdownButtonFormField<String>).at(index);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  group('WelcomePage profile form', () {
    testWidgets('shows validation errors for empty required fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: WelcomePage(db: db)));

      await tester.ensureVisible(submitButton());
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text('Please select your gender'), findsOneWidget);
      expect(find.text('Please enter your age'), findsOneWidget);
      expect(find.text('Enter weight'), findsOneWidget);
      expect(find.text('Enter height'), findsOneWidget);
      expect(find.text('Please select your activity level'), findsOneWidget);

      // Nothing should be saved when validation fails.
      expect(await db.select(db.userProfiles).get(), isEmpty);
    });

    testWidgets('saves a valid profile with computed nutrition targets', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: WelcomePage(db: db)));

      await selectDropdown(tester, 0, 'Male');
      await tester.enterText(fieldWithLabel('Age'), '29');
      await tester.enterText(fieldWithLabel('Weight (kg)'), '72');
      await tester.enterText(fieldWithLabel('Height (cm)'), '175');
      await selectDropdown(tester, 1, 'Moderate (Exercise 3-5 days/week)');
      await tester.enterText(
        fieldWithLabel('Preferences / Allergies'),
        'vegetarian, no seafood',
      );

      await tester.ensureVisible(submitButton());
      await tester.tap(submitButton());
      // Let the database write finish, then show the snackbar.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      final profiles = await db.select(db.userProfiles).get();
      expect(profiles, hasLength(1));
      final profile = profiles.single;
      expect(profile.gender, 'Male');
      expect(profile.age, 29);
      expect(profile.weight, 72);
      expect(profile.height, 175);
      expect(profile.preferences, 'vegetarian, no seafood');
      expect(profile.dailyCalories, greaterThan(0));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isFirstTime'), isFalse);
      expect(find.text('Profile saved successfully!'), findsOneWidget);
    });
  });
}
