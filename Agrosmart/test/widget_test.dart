import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_application/main.dart';

void main() {
  testWidgets('renders the AgroSmart AI login experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AgroSmartApp());

    expect(find.text('AgroSmart AI'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets('password visibility toggle reveals the password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AgroSmartApp());

    await tester.enterText(find.byType(TextFormField).last, 'secret');
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isTrue,
    );

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isFalse,
    );
  });
}
