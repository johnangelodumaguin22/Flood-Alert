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
}
