import 'package:flutter_test/flutter_test.dart';

import 'package:my_application/models/stock_product.dart';
import 'package:my_application/services/stock_question_parser.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  final products = [
    StockProduct(
      id: 1,
      name: 'Fongicide BioProtect',
      category: ProductCategory.traitement,
      unit: 'L',
      totalQuantity: 8,
      minThreshold: 5,
      createdAt: now,
      updatedAt: now,
    ),
    StockProduct(
      id: 2,
      name: 'Engrais NPK 15-15-15',
      category: ProductCategory.engrais,
      unit: 'kg',
      totalQuantity: 40,
      minThreshold: 50,
      createdAt: now,
      updatedAt: now,
    ),
    StockProduct(
      id: 3,
      name: 'Semences de maïs hybride',
      category: ProductCategory.semences,
      unit: 'kg',
      totalQuantity: 18,
      minThreshold: 20,
      createdAt: now,
      updatedAt: now,
    ),
    StockProduct(
      id: 4,
      name: 'Médicament vétérinaire',
      category: ProductCategory.medicaments,
      unit: 'unité',
      totalQuantity: 12,
      minThreshold: 3,
      createdAt: now,
      updatedAt: now,
    ),
    StockProduct(
      id: 5,
      name: 'Engrais azoté',
      category: ProductCategory.engrais,
      unit: 'kg',
      totalQuantity: 12,
      minThreshold: 20,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final parser = const RuleBasedQuestionParser();

  group('normalisation', () {
    test('retire accents, ponctuation et majuscules', () {
      expect(normalizeFrench('État du stock !'), 'etat du stock');
    });

    test('calcule la distance de Levenshtein', () {
      expect(levenshtein('bioprotec', 'bioprotect'), 1);
    });
  });

  group('jeu de 40 questions réalistes', () {
    final cases = <({String question, StockQuestionIntent intent})>[
      (
        question: 'Que dois-je réapprovisionner ?',
        intent: StockQuestionIntent.reorder,
      ),
      (
        question: 'Quels produits commander ?',
        intent: StockQuestionIntent.reorder,
      ),
      (question: 'Ai-je besoin d achat ?', intent: StockQuestionIntent.reorder),
      (
        question: 'Que faut il acheter pour les semences ?',
        intent: StockQuestionIntent.reorder,
      ),
      (
        question: 'Quels produits sont à réappro ?',
        intent: StockQuestionIntent.reorder,
      ),
      (
        question: 'Quels lots expirent bientôt ?',
        intent: StockQuestionIntent.expiration,
      ),
      (
        question: 'Qu est-ce qui est périmé ?',
        intent: StockQuestionIntent.expiration,
      ),
      (
        question: 'Montre les dates limites',
        intent: StockQuestionIntent.expiration,
      ),
      (
        question: 'Les traitements expirent-ils ce mois ?',
        intent: StockQuestionIntent.expiration,
      ),
      (
        question: 'Y a t il une alerte expiration ?',
        intent: StockQuestionIntent.expiration,
      ),
      (
        question: 'Quels stocks sont faibles ?',
        intent: StockQuestionIntent.lowStock,
      ),
      (
        question: 'Qu est sous le seuil ?',
        intent: StockQuestionIntent.lowStock,
      ),
      (
        question: 'Montre les niveaux bas',
        intent: StockQuestionIntent.lowStock,
      ),
      (
        question: 'Ai-je une alerte stock ?',
        intent: StockQuestionIntent.lowStock,
      ),
      (
        question: 'Quels produits ont peu de stock ?',
        intent: StockQuestionIntent.lowStock,
      ),
      (
        question: 'Quelle quantité de BioProtect ?',
        intent: StockQuestionIntent.productQuantity,
      ),
      (
        question: 'Combien reste-t-il de NPK ?',
        intent: StockQuestionIntent.productQuantity,
      ),
      (
        question: 'Stock de semences de maïs hybride',
        intent: StockQuestionIntent.productQuantity,
      ),
      (
        question: 'Quel est le stock du bioprotec ?',
        intent: StockQuestionIntent.productQuantity,
      ),
      (
        question: 'Combien ai-je d engrais ?',
        intent: StockQuestionIntent.productQuantity,
      ),
      (
        question: 'Donne-moi le résumé de l inventaire',
        intent: StockQuestionIntent.inventorySummary,
      ),
      (
        question: 'Quel est l état du stock ?',
        intent: StockQuestionIntent.inventorySummary,
      ),
      (
        question: 'Résumé des stocks',
        intent: StockQuestionIntent.inventorySummary,
      ),
      (
        question: 'Combien de produits en inventaire ?',
        intent: StockQuestionIntent.inventorySummary,
      ),
      (
        question: 'Fais un bilan de l inventaire',
        intent: StockQuestionIntent.inventorySummary,
      ),
      (
        question: 'Quels sont les mouvements ?',
        intent: StockQuestionIntent.movements,
      ),
      (
        question: 'Montre les entrées et sorties',
        intent: StockQuestionIntent.movements,
      ),
      (question: 'Historique du stock', intent: StockQuestionIntent.movements),
      (
        question: 'Quelles sorties ce mois ?',
        intent: StockQuestionIntent.movements,
      ),
      (
        question: 'Mouvements de NPK hier',
        intent: StockQuestionIntent.movements,
      ),
      (question: 'Fais le rapport du mois', intent: StockQuestionIntent.report),
      (
        question: 'Quel est le bilan mensuel ?',
        intent: StockQuestionIntent.report,
      ),
      (
        question: 'Y a-t-il eu des pertes ?',
        intent: StockQuestionIntent.report,
      ),
      (question: 'Rapport de novembre', intent: StockQuestionIntent.report),
      (
        question: 'Rapport des sorties du mois dernier',
        intent: StockQuestionIntent.report,
      ),
      (
        question: 'Quel dosage pour le fongicide ?',
        intent: StockQuestionIntent.medicationUsage,
      ),
      (
        question: 'Comment utiliser ce médicament ?',
        intent: StockQuestionIntent.medicationUsage,
      ),
      (
        question: 'Quelle posologie prescrite ?',
        intent: StockQuestionIntent.medicationUsage,
      ),
      (question: 'Quelle météo demain ?', intent: StockQuestionIntent.offTopic),
      (question: 'Bonjour, qui es-tu ?', intent: StockQuestionIntent.offTopic),
    ];

    for (final testCase in cases) {
      test(testCase.question, () {
        expect(
          parser.parse(testCase.question, products: products).intent,
          testCase.intent,
        );
      });
    }
  });

  test('extrait catégorie, période, mois et jours', () {
    final result = parser.parse(
      'Mouvements des engrais les 30 derniers jours en novembre',
      products: products,
    );
    expect(result.category, ProductCategory.engrais);
    expect(result.period, StockQuestionPeriod.last30Days);
    expect(result.month, 11);
    expect(result.days, 30);
  });

  test('tolère une faute de frappe sur le produit', () {
    final result = parser.parse('quantité du bioprotec', products: products);
    expect(result.product?.id, 1);
  });

  test('retourne plusieurs produits ambigus', () {
    final result = parser.parse('combien pour l engrais', products: products);
    expect(result.isAmbiguous, isTrue);
    expect(result.productCandidates.length, 2);
  });

  test('retourne une intention inconnue avec aide', () {
    final result = parser.parse('xyz abc', products: products);
    expect(result.intent, StockQuestionIntent.unknown);
    expect(result.helpMessage, isNotNull);
  });
}
