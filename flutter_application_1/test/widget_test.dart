// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('Workout Launcher Screen test', (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(MyApp(db: db));
    await tester.pumpAndSettle();

    // Verify that our Workout Launcher screen is shown.
    expect(find.text('Aegymer Workout'), findsOneWidget);
    expect(find.text('Your Routine'), findsOneWidget);
  });
}
