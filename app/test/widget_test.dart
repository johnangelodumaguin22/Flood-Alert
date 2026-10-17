import 'package:flood_alert/screens/levels_sheet.dart';
import 'package:flood_alert/screens/login_screen.dart';
import 'package:flood_alert/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login shows validation errors when empty', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const LoginScreen()));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter your email or username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('levels sheet rejects warning at or above critical', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLevelsSheet(context, warnCm: 65, critCm: 85, maxCm: 100),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '90');
    await tester.enterText(fields.at(1), '120');
    await tester.tap(find.text('Save levels'));
    await tester.pump();
    expect(find.text('Must be lower than the critical level.'), findsNothing);
    expect(find.text('Must be at most 100 cm, the top of the gauge.'), findsOneWidget);
    await tester.enterText(fields.at(1), '80');
    await tester.tap(find.text('Save levels'));
    await tester.pump();
    expect(find.text('Must be lower than the critical level.'), findsOneWidget);
  });
}
