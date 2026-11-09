import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/mock_parcel_health_repository.dart';

import 'package:my_application/models/drone.dart';
import 'package:my_application/models/parcel_health.dart';
import 'package:my_application/providers/parcel_health_provider.dart';
import 'package:my_application/screens/parcel_health_map_screen.dart';

void main() {
  test('filters anomalies by type and severity', () async {
    final provider = ParcelHealthProvider(MockParcelHealthRepository());
    await provider.load();

    expect(provider.selectedParcel?.name, 'Tomato Field A');
    expect(provider.filteredAnomalies, hasLength(8));

    provider.setTypeFilter(AnomalyType.disease);
    expect(provider.filteredAnomalies, hasLength(2));

    provider.setSeverityFilter(Severity.critical);
    expect(provider.filteredAnomalies.single.name, 'Early Blight');
  });

  test('assigns drones to the selected parcel', () async {
    final repository = MockParcelHealthRepository()
      ..drones.addAll(const [
        Drone(
          id: 'd1',
          name: 'Faucon',
          brand: 'DJI',
          model: 'Mavic 3M',
          type: DroneType.multispectral,
          status: DroneStatus.active,
        ),
        Drone(
          id: 'd2',
          name: 'Aigle',
          brand: 'DJI',
          model: 'Agras T40',
          type: DroneType.spraying,
          status: DroneStatus.maintenance,
        ),
      ]);
    final provider = ParcelHealthProvider(repository);
    await provider.load();

    expect(provider.drones, hasLength(2));
    expect(provider.parcelDrones, isEmpty);

    await provider.setParcelDrones({'d1', 'd2'});
    expect(provider.parcelDrones.map((d) => d.name), ['Faucon', 'Aigle']);

    // Each parcel keeps its own drones.
    await provider.selectParcel(provider.parcels[1]);
    expect(provider.parcelDrones, isEmpty);
    await provider.selectParcel(provider.parcels[0]);
    expect(provider.parcelDroneIds, {'d1', 'd2'});
  });

  test('saving a parcel adds it and selects it', () async {
    final provider = ParcelHealthProvider(MockParcelHealthRepository());
    await provider.load();

    await provider.saveParcel(
      const Parcel(
        id: 'parcel-new',
        name: 'Olive Grove',
        cropType: 'Olives',
        surfaceHectares: 1,
        boundary: [
          LatLng(36.680, 10.590),
          LatLng(36.680, 10.591),
          LatLng(36.679, 10.591),
          LatLng(36.679, 10.590),
        ],
      ),
    );

    expect(provider.parcels, hasLength(3));
    expect(provider.selectedParcel?.name, 'Olive Grove');
    expect(provider.analysis, isNull);

    await provider.deleteParcel('parcel-new');
    expect(provider.parcels, hasLength(2));
    expect(provider.selectedParcel?.name, 'Tomato Field A');
  });

  testWidgets('renders parcel info, filters and statistics', (tester) async {
    // Test fonts render wider than real ones, so use a roomy viewport.
    tester.view.physicalSize = const Size(1800, 4800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ParcelHealthMapScreen(repository: MockParcelHealthRepository()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Parcel Health Map'), findsOneWidget);
    expect(find.text('Tomato Field A'), findsWidgets);
    expect(find.text('Last mission: 01/11/2026'), findsOneWidget);
    expect(find.text('Water Stress'), findsOneWidget);
    expect(find.text('8 markers'), findsOneWidget);

    await tester.tap(find.text('Weed Detection'));
    await tester.pump();
    expect(find.text('2 markers'), findsOneWidget);
  });
}
