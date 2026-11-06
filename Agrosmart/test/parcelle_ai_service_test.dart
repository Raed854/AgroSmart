import 'package:flutter_test/flutter_test.dart';
import 'package:my_application/models/parcelle_model.dart';
import 'package:my_application/services/parcelle_ai_service.dart';

void main() {
  group('ParcelleAIService - suggestCrops', () {
    late ParcelleAIService aiService;

    setUp(() {
      aiService = ParcelleAIService();
    });

    test('should suggest crops for clay soil (argileux)', () {
      final crops = aiService.suggestCrops('Argileux');
      expect(crops, isNotEmpty);
      expect(crops, contains('Blé'));
      expect(crops, contains('Colza'));
    });

    test('should suggest crops for sandy soil (sableux)', () {
      final crops = aiService.suggestCrops('Sableux');
      expect(crops, isNotEmpty);
      expect(crops, contains('Carotte'));
      expect(crops, contains('Asperge'));
    });

    test('should suggest crops for silty soil (limoneux)', () {
      final crops = aiService.suggestCrops('Limoneux');
      expect(crops, isNotEmpty);
      expect(crops, contains('Maïs'));
      expect(crops, contains('Tomate'));
    });

    test('should suggest crops for clay-silty soil (argileux-limoneux)', () {
      final crops = aiService.suggestCrops('Argileux-limoneux');
      expect(crops, isNotEmpty);
      expect(crops, contains('Blé'));
      expect(crops, contains('Maïs'));
    });

    test('should suggest crops for sandy-silty soil (sablo-limoneux)', () {
      final crops = aiService.suggestCrops('Sablo-limoneux');
      expect(crops, isNotEmpty);
      expect(crops, contains('Pomme de terre'));
      expect(crops, contains('Carotte'));
    });

    test('should suggest crops for clay-sandy soil (argileux-sableux)', () {
      final crops = aiService.suggestCrops('Argileux-sableux');
      expect(crops, isNotEmpty);
      expect(crops, contains('Orge'));
      expect(crops, contains('Tournesol'));
    });

    test('should suggest crops for humic soil (humifère)', () {
      final crops = aiService.suggestCrops('Humifère');
      expect(crops, isNotEmpty);
      expect(crops, contains('Laitue'));
      expect(crops, contains('Tomate'));
    });

    test('should suggest crops for limestone soil (calcaire)', () {
      final crops = aiService.suggestCrops('Calcaire');
      expect(crops, isNotEmpty);
      expect(crops, contains('Orge'));
      expect(crops, contains('Olivier'));
    });

    test('should handle case insensitive soil types', () {
      final cropsLower = aiService.suggestCrops('argileux');
      final cropsUpper = aiService.suggestCrops('ARGILEUX');
      final cropsMixed = aiService.suggestCrops('ArGiLeUx');

      expect(cropsLower, equals(cropsUpper));
      expect(cropsLower, equals(cropsMixed));
    });

    test('should return default crops for unknown soil type', () {
      final crops = aiService.suggestCrops('Type inconnu');
      expect(crops, isNotEmpty);
      expect(crops.length, greaterThanOrEqualTo(4));
    });
  });

  group('ParcelleAIService - detectAnomalies', () {
    late ParcelleAIService aiService;

    setUp(() {
      aiService = ParcelleAIService();
    });

    test('should detect GPS coordinates outside Tunisia', () {
      final parcelle = ParcelleModel(
        id: '1',
        nom: 'Test Parcelle',
        surface: 5.0,
        latitude: 48.8566, // Paris - outside Tunisia
        longitude: 2.3522,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final anomalies = aiService.detectAnomalies(parcelle, [parcelle]);
      expect(anomalies, isNotEmpty);
      expect(
        anomalies.any((a) => a.contains('Coordonnées GPS inhabituelles')),
        isTrue,
      );
    });

    test('should not detect anomalies for valid Tunisia GPS coordinates', () {
      final parcelle = ParcelleModel(
        id: '1',
        nom: 'Test Parcelle',
        surface: 5.0,
        latitude: 36.8065, // Tunis
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final anomalies = aiService.detectAnomalies(parcelle, [parcelle]);
      final hasGPSAnomaly = anomalies.any(
        (a) => a.contains('Coordonnées GPS inhabituelles'),
      );
      expect(hasGPSAnomaly, isFalse);
    });

    test('should detect unusually large surface area', () {
      final smallParcelle1 = ParcelleModel(
        id: '1',
        nom: 'Petite 1',
        surface: 2.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final smallParcelle2 = ParcelleModel(
        id: '2',
        nom: 'Petite 2',
        surface: 3.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final largeParcelle = ParcelleModel(
        id: '3',
        nom: 'Grande',
        surface: 25.0, // More than 3x average (2.5)
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final allParcelles = [smallParcelle1, smallParcelle2, largeParcelle];
      final anomalies = aiService.detectAnomalies(largeParcelle, allParcelles);

      expect(anomalies, isNotEmpty);
      expect(
        anomalies.any((a) => a.contains('Variation inhabituelle à vérifier')),
        isTrue,
      );
    });

    test('should detect near-duplicate GPS locations', () {
      final parcelle1 = ParcelleModel(
        id: '1',
        nom: 'Parcelle 1',
        surface: 5.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final parcelle2 = ParcelleModel(
        id: '2',
        nom: 'Parcelle 2',
        surface: 5.0,
        latitude: 36.8066, // Very close to parcelle1 (< 100m)
        longitude: 10.1816,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final allParcelles = [parcelle1, parcelle2];
      final anomalies = aiService.detectAnomalies(parcelle1, allParcelles);

      expect(anomalies, isNotEmpty);
      expect(
        anomalies.any((a) => a.contains('Position très proche')),
        isTrue,
      );
    });

    test('should detect empty name', () {
      final parcelle = ParcelleModel(
        id: '1',
        nom: '',
        surface: 5.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final anomalies = aiService.detectAnomalies(parcelle, [parcelle]);
      expect(anomalies, isNotEmpty);
      expect(
        anomalies.any((a) => a.contains('Nom de parcelle vide')),
        isTrue,
      );
    });

    test('should detect invalid surface (zero or negative)', () {
      final parcelle = ParcelleModel(
        id: '1',
        nom: 'Test',
        surface: 0.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final anomalies = aiService.detectAnomalies(parcelle, [parcelle]);
      expect(anomalies, isNotEmpty);
      expect(
        anomalies.any((a) => a.contains('Surface') && a.contains('invalide')),
        isTrue,
      );
    });

    test('should detect missing soil type', () {
      final parcelle = ParcelleModel(
        id: '1',
        nom: 'Test',
        surface: 5.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: '',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final anomalies = aiService.detectAnomalies(parcelle, [parcelle]);
      expect(anomalies, isNotEmpty);
      expect(
        anomalies.any((a) => a.contains('Type de sol non renseigné')),
        isTrue,
      );
    });

    test('should return empty list for valid parcelle', () {
      final parcelle = ParcelleModel(
        id: '1',
        nom: 'Valid Parcelle',
        surface: 5.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final anomalies = aiService.detectAnomalies(parcelle, [parcelle]);
      expect(anomalies, isEmpty);
    });
  });

  group('ParcelleAIService - compareParcelles', () {
    late ParcelleAIService aiService;

    setUp(() {
      aiService = ParcelleAIService();
    });

    test('should return zero values for empty list', () {
      final comparison = aiService.compareParcelles([]);

      expect(comparison['totalArea'], equals(0.0));
      expect(comparison['averageArea'], equals(0.0));
      expect(comparison['largest'], isNull);
      expect(comparison['smallest'], isNull);
      expect(comparison['countBySoilType'], isEmpty);
      expect(comparison['totalCount'], equals(0));
    });

    test('should calculate correct total and average area', () {
      final parcelles = [
        ParcelleModel(
          id: '1',
          nom: 'P1',
          surface: 5.0,
          latitude: 36.8065,
          longitude: 10.1815,
          typeSol: 'Argileux',
          archivee: false,
          createdAt: DateTime.now(),
        ),
        ParcelleModel(
          id: '2',
          nom: 'P2',
          surface: 3.0,
          latitude: 36.8065,
          longitude: 10.1815,
          typeSol: 'Sableux',
          archivee: false,
          createdAt: DateTime.now(),
        ),
        ParcelleModel(
          id: '3',
          nom: 'P3',
          surface: 7.0,
          latitude: 36.8065,
          longitude: 10.1815,
          typeSol: 'Limoneux',
          archivee: false,
          createdAt: DateTime.now(),
        ),
      ];

      final comparison = aiService.compareParcelles(parcelles);

      expect(comparison['totalArea'], equals(15.0));
      expect(comparison['averageArea'], equals(5.0));
      expect(comparison['totalCount'], equals(3));
    });

    test('should identify largest and smallest parcelles', () {
      final small = ParcelleModel(
        id: '1',
        nom: 'Small',
        surface: 2.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Argileux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final medium = ParcelleModel(
        id: '2',
        nom: 'Medium',
        surface: 5.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Sableux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final large = ParcelleModel(
        id: '3',
        nom: 'Large',
        surface: 10.0,
        latitude: 36.8065,
        longitude: 10.1815,
        typeSol: 'Limoneux',
        archivee: false,
        createdAt: DateTime.now(),
      );

      final parcelles = [medium, small, large];
      final comparison = aiService.compareParcelles(parcelles);

      expect((comparison['largest'] as ParcelleModel).id, equals('3'));
      expect((comparison['smallest'] as ParcelleModel).id, equals('1'));
    });

    test('should count parcelles by soil type', () {
      final parcelles = [
        ParcelleModel(
          id: '1',
          nom: 'P1',
          surface: 5.0,
          latitude: 36.8065,
          longitude: 10.1815,
          typeSol: 'Argileux',
          archivee: false,
          createdAt: DateTime.now(),
        ),
        ParcelleModel(
          id: '2',
          nom: 'P2',
          surface: 3.0,
          latitude: 36.8065,
          longitude: 10.1815,
          typeSol: 'Argileux',
          archivee: false,
          createdAt: DateTime.now(),
        ),
        ParcelleModel(
          id: '3',
          nom: 'P3',
          surface: 7.0,
          latitude: 36.8065,
          longitude: 10.1815,
          typeSol: 'Sableux',
          archivee: false,
          createdAt: DateTime.now(),
        ),
        ParcelleModel(
          id: '4',
          nom: 'P4',
          surface: 4.0,
          latitude: 36.8065,
          longitude: 10.1815,
          typeSol: 'Limoneux',
          archivee: false,
          createdAt: DateTime.now(),
        ),
      ];

      final comparison = aiService.compareParcelles(parcelles);
      final countBySoilType =
          comparison['countBySoilType'] as Map<String, int>;

      expect(countBySoilType['Argileux'], equals(2));
      expect(countBySoilType['Sableux'], equals(1));
      expect(countBySoilType['Limoneux'], equals(1));
    });

    test('should handle single parcelle', () {
      final parcelles = [
        ParcelleModel(
          id: '1',
          nom: 'Single',
          surface: 5.0,
          latitude: 36.8065,
          longitude: 10.1815,
          typeSol: 'Argileux',
          archivee: false,
          createdAt: DateTime.now(),
        ),
      ];

      final comparison = aiService.compareParcelles(parcelles);

      expect(comparison['totalArea'], equals(5.0));
      expect(comparison['averageArea'], equals(5.0));
      expect((comparison['largest'] as ParcelleModel).id, equals('1'));
      expect((comparison['smallest'] as ParcelleModel).id, equals('1'));
      expect(comparison['totalCount'], equals(1));
    });
  });
}
