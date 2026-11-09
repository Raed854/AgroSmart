import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_application/screens/dashboard_screen.dart';

void main() {
  testWidgets('Farm management "Drone" opens the drone creation page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.tap(find.text('Drone'));
    await tester.pumpAndSettle();

    expect(find.text('Nouveau drone'), findsOneWidget);
    expect(find.text('Créer le drone'), findsOneWidget);
    expect(find.text('Image du drone'), findsNothing);
    expect(find.text('Ajouter une image du drone'), findsOneWidget);
  });
}
