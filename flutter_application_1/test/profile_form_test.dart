import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/presentation/welcome_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('WelcomePage profile form', () {
    testWidgets('shows validation errors for empty required fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomePage(),
        ),
      );

      final okayButton = find.text('Okay');

      await tester.ensureVisible(okayButton);

      await tester.tap(okayButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please select your gender'), findsOneWidget);
      expect(find.text('Please enter your age'), findsOneWidget);
      expect(find.text('Please enter your weight'), findsOneWidget);
      expect(find.text('Please enter your height'), findsOneWidget);
      expect(find.text('Please select your activity level'), findsOneWidget);
      expect(find.text('Please enter your target'), findsOneWidget);
    });
    testWidgets('submits a valid profile and navigates away', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: WelcomePage()));

      await tester.enterText(find.byType(TextFormField).at(0), 'kaka');

      final genderField = find.byType(DropdownButtonFormField<String>).at(0);
      await tester.tap(genderField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Male').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), '29');
      await tester.enterText(find.byType(TextFormField).at(2), '72');
      await tester.enterText(find.byType(TextFormField).at(3), '175');

      final activityField = find.byType(DropdownButtonFormField<String>).at(1);
      await tester.tap(activityField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moderate Exercise (3-5 days/week)').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(4), 'maintain');
      await tester.enterText(find.byType(TextFormField).at(5), 'vegetarian, no seafood');

      await tester.tap(find.text('Okay'));

await tester.pump();
await tester.pump(const Duration(milliseconds: 500));

expect(
  find.text('Profile saved successfully'),
  findsOneWidget,
);

      expect(find.text('Profile saved successfully'), findsOneWidget);
    });
  });
}
