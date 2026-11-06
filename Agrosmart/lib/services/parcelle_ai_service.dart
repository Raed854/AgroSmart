import 'dart:math';

import '../models/parcelle_model.dart';

/// Service d'assistance IA pour les parcelles (règles simples, sur appareil)
/// Ces suggestions sont indicatives, basées sur des règles simples.
class ParcelleAIService {
  // Constantes pour la détection d'anomalies
  static const double _tunisiaLatMin = 30.0;
  static const double _tunisiaLatMax = 38.0;
  static const double _tunisiaLngMin = 7.0;
  static const double _tunisiaLngMax = 12.0;
  static const double _surfaceMultiplier = 3.0;
  static const double _duplicateDistanceThresholdMeters = 100.0;

  /// Suggère des cultures adaptées au type de sol
  /// Retourne une liste de noms de cultures couramment adaptées
  List<String> suggestCrops(String typeSol) {
    final normalizedSol = typeSol.toLowerCase().trim();

    // Vérifier les combinaisons composées en premier
    if (normalizedSol.contains('argileux') && normalizedSol.contains('limoneux')) {
      return ['Blé', 'Maïs', 'Betterave', 'Tomate', 'Chou'];
    } else if (normalizedSol.contains('argileux') && (normalizedSol.contains('sableux') || normalizedSol.contains('sable'))) {
      return ['Orge', 'Tournesol', 'Pomme de terre', 'Carotte'];
    } else if ((normalizedSol.contains('sablo') || normalizedSol.contains('sableux') || normalizedSol.contains('sable')) && normalizedSol.contains('limoneux')) {
      return ['Pomme de terre', 'Carotte', 'Asperge', 'Tomate', 'Melon'];
    }
    
    // Vérifier les types simples
    if (normalizedSol.contains('argileux')) {
      return ['Blé', 'Colza', 'Betterave', 'Chou', 'Haricot'];
    } else if (normalizedSol.contains('sablo') || normalizedSol.contains('sableux') || normalizedSol.contains('sable')) {
      return ['Carotte', 'Asperge', 'Arachide', 'Melon', 'Pastèque'];
    } else if (normalizedSol.contains('limoneux')) {
      return ['Maïs', 'Tomate', 'Laitue', 'Poivron', 'Aubergine', 'Courgette'];
    } else if (normalizedSol.contains('humifère')) {
      return ['Laitue', 'Tomate', 'Poivron', 'Courgette', 'Haricot'];
    } else if (normalizedSol.contains('calcaire')) {
      return ['Orge', 'Olivier', 'Vigne', 'Luzerne', 'Pois chiche'];
    } else {
      // Type de sol inconnu ou autre
      return ['Maïs', 'Tomate', 'Pomme de terre', 'Carotte', 'Laitue'];
    }
  }

  /// Détecte des anomalies potentielles pour une parcelle
  /// Retourne une liste de points à vérifier
  List<String> detectAnomalies(
    ParcelleModel parcelle,
    List<ParcelleModel> allParcelles,
  ) {
    final anomalies = <String>[];

    // 1. Vérifier si les coordonnées GPS sont en dehors de la Tunisie
    if (parcelle.latitude < _tunisiaLatMin ||
        parcelle.latitude > _tunisiaLatMax ||
        parcelle.longitude < _tunisiaLngMin ||
        parcelle.longitude > _tunisiaLngMax) {
      anomalies.add(
        'Coordonnées GPS inhabituelles pour la Tunisie '
        '(${parcelle.latitude.toStringAsFixed(2)}, ${parcelle.longitude.toStringAsFixed(2)})',
      );
    }

    // 2. Vérifier si la surface est anormalement grande
    final otherParcelles =
        allParcelles.where((p) => p.id != parcelle.id).toList();
    if (otherParcelles.isNotEmpty) {
      final averageSurface = otherParcelles.fold<double>(
            0.0,
            (sum, p) => sum + p.surface,
          ) /
          otherParcelles.length;

      if (parcelle.surface > averageSurface * _surfaceMultiplier) {
        anomalies.add(
          'Surface ${parcelle.surface.toStringAsFixed(1)} ha est ${(parcelle.surface / averageSurface).toStringAsFixed(1)}x '
          'la moyenne (${averageSurface.toStringAsFixed(1)} ha). Variation inhabituelle à vérifier.',
        );
      }
    }

    // 3. Vérifier les GPS quasi-identiques avec d'autres parcelles
    for (final other in allParcelles) {
      if (other.id == parcelle.id) continue;

      final distance = _calculateDistance(
        parcelle.latitude,
        parcelle.longitude,
        other.latitude,
        other.longitude,
      );

      if (distance < _duplicateDistanceThresholdMeters) {
        anomalies.add(
          'Position très proche de "${other.nom}" '
          '(${distance.toStringAsFixed(0)} m). Vérifier si c\'est voulu.',
        );
      }
    }

    // 4. Vérifier les données manquantes ou invalides
    if (parcelle.nom.trim().isEmpty) {
      anomalies.add('Nom de parcelle vide ou invalide.');
    }

    if (parcelle.surface <= 0) {
      anomalies.add(
        'Surface ${parcelle.surface.toStringAsFixed(1)} ha est invalide. '
        'Doit être supérieure à 0.',
      );
    }

    if (parcelle.typeSol.trim().isEmpty) {
      anomalies.add('Type de sol non renseigné.');
    }

    return anomalies;
  }

  /// Compare toutes les parcelles et retourne un résumé statistique
  Map<String, dynamic> compareParcelles(List<ParcelleModel> allParcelles) {
    if (allParcelles.isEmpty) {
      return {
        'totalArea': 0.0,
        'averageArea': 0.0,
        'largest': null,
        'smallest': null,
        'countBySoilType': <String, int>{},
        'totalCount': 0,
      };
    }

    // Surface totale
    final totalArea = allParcelles.fold<double>(
      0.0,
      (sum, p) => sum + p.surface,
    );

    // Surface moyenne
    final averageArea = totalArea / allParcelles.length;

    // Plus grande et plus petite parcelle
    var largest = allParcelles.first;
    var smallest = allParcelles.first;

    for (final parcelle in allParcelles) {
      if (parcelle.surface > largest.surface) {
        largest = parcelle;
      }
      if (parcelle.surface < smallest.surface) {
        smallest = parcelle;
      }
    }

    // Comptage par type de sol
    final countBySoilType = <String, int>{};
    for (final parcelle in allParcelles) {
      final soilType = parcelle.typeSol;
      countBySoilType[soilType] = (countBySoilType[soilType] ?? 0) + 1;
    }

    return {
      'totalArea': totalArea,
      'averageArea': averageArea,
      'largest': largest,
      'smallest': smallest,
      'countBySoilType': countBySoilType,
      'totalCount': allParcelles.length,
    };
  }

  /// Calcule la distance en mètres entre deux points GPS (formule de Haversine)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c * 1000; // Convertir en mètres
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
