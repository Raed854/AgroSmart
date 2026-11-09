// Service de suggestions de réapprovisionnement (IA locale) – module 3.6
// Logique simple et explicable, sans API externe.

import '../models/stock_movement.dart';
import '../models/stock_product.dart';

/// Résultat d'une suggestion pour un produit.
class ReorderSuggestion {
  const ReorderSuggestion({
    required this.product,
    required this.windowDays,
    required this.avgDailyConsumption,
    required this.daysOfCoverage,
    required this.estimatedStockoutDate,
    required this.suggestedQuantity,
  });

  final StockProduct product;

  /// Fenêtre d'analyse en jours (30, 60 ou 90).
  final int windowDays;

  /// Consommation moyenne journalière sur la fenêtre.
  final double avgDailyConsumption;

  /// Jours de stock restants au rythme actuel.
  final double daysOfCoverage;

  /// Date estimée de rupture.
  final DateTime estimatedStockoutDate;

  /// Quantité suggérée à commander (pour couvrir [leadTimeDays] jours).
  final double suggestedQuantity;
}

/// Message renvoyé si l'historique est insuffisant.
class InsufficientHistoryResult {
  const InsufficientHistoryResult({
    required this.product,
    required this.movementCount,
  });

  final StockProduct product;
  final int movementCount;
}

/// Scellé pour typer le résultat : suggestion OU historique insuffisant.
sealed class SuggestionResult {
  const SuggestionResult();
}

class SuggestionOk extends SuggestionResult {
  const SuggestionOk(this.suggestion);
  final ReorderSuggestion suggestion;
}

class SuggestionNoHistory extends SuggestionResult {
  const SuggestionNoHistory(this.info);
  final InsufficientHistoryResult info;
}

class ReorderSuggestionService {
  const ReorderSuggestionService();

  /// Seuil minimal de mouvements de sortie pour calculer une suggestion.
  static const int minMovements = 5;

  /// Jours de couverture cibles pour calculer la quantité suggérée.
  static const int _leadTimeDays = 30;

  /// Calcule une suggestion pour [product] à partir de [sortieMovements].
  ///
  /// [sortieMovements] doit contenir uniquement les mouvements de type SORTIE
  /// du produit, sur la période analysée.
  SuggestionResult compute({
    required StockProduct product,
    required List<StockMovement> sortieMovements,
    required int windowDays,
  }) {
    if (sortieMovements.length < minMovements) {
      return SuggestionNoHistory(
        InsufficientHistoryResult(
          product: product,
          movementCount: sortieMovements.length,
        ),
      );
    }

    final totalConsumed = sortieMovements.fold<double>(
      0,
      (sum, m) => sum + m.quantity,
    );

    if (windowDays <= 0 || totalConsumed <= 0) {
      return SuggestionNoHistory(
        InsufficientHistoryResult(
          product: product,
          movementCount: sortieMovements.length,
        ),
      );
    }

    final avg = totalConsumed / windowDays;
    final coverage = avg > 0 ? product.totalQuantity / avg : double.infinity;
    final stockoutDate = DateTime.now().add(
      Duration(days: coverage.isFinite ? coverage.round() : 9999),
    );
    final suggested = avg * _leadTimeDays;

    return SuggestionOk(
      ReorderSuggestion(
        product: product,
        windowDays: windowDays,
        avgDailyConsumption: avg,
        daysOfCoverage: coverage,
        estimatedStockoutDate: stockoutDate,
        suggestedQuantity: suggested,
      ),
    );
  }
}
