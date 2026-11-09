import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/mock_parcel_health_data.dart';

import 'package:my_application/models/parcel_health.dart';
import 'package:my_application/screens/parcel_editor_screen.dart';
import 'package:my_application/utils/geo_utils.dart';

void main() {
  test('orders corners and computes the area in hectares', () {
    // Corners entered in a "crossed" order: 1, 3, 2, 4.
    final crossed = [
      tomatoFieldA.boundary[0],
      tomatoFieldA.boundary[2],
      tomatoFieldA.boundary[1],
      tomatoFieldA.boundary[3],
    ];
    final ordered = orderPolygon(crossed);

    expect(polygonAreaHectares(ordered), closeTo(2.78, 0.05));
    // Unordered corners would give a self-crossing, much smaller shape.
    expect(polygonAreaHectares(crossed), lessThan(1));
  });

  testWidgets('creates a parcel from 4 typed corner points', (tester) async {
    tester.view.physicalSize = const Size(1800, 4800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Parcel? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ParcelEditorScreen(
                  onSave: (parcel) async => saved = parcel,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    const corners = [
      LatLng(36.6800, 10.5900),
      LatLng(36.6800, 10.5920),
      LatLng(36.6790, 10.5920),
      LatLng(36.6790, 10.5900),
    ];
    final fields = find.byType(TextField);
    for (var i = 0; i < corners.length; i++) {
      await tester.enterText(fields.at(i * 2), '${corners[i].latitude}');
      await tester.enterText(fields.at(i * 2 + 1), '${corners[i].longitude}');
    }
    await tester.enterText(fields.at(8), 'Tomato Field C');
    await tester.pump();

    expect(find.text('4/4 set'), findsOneWidget);
    expect(find.textContaining('Calculated surface'), findsOneWidget);

    await tester.tap(find.text('Create parcel'));
    await tester.pumpAndSettle();

    expect(saved?.name, 'Tomato Field C');
    expect(saved?.cropType, 'Tomatoes');
    expect(saved?.boundary, hasLength(4));
    // ~178 m x ~111 m.
    expect(saved?.surfaceHectares, closeTo(1.98, 0.05));
    expect(find.text('open'), findsOneWidget);
  });
}
