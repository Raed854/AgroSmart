import 'dart:math' as math;

import '../models/stock_product.dart';

enum StockQuestionIntent {
  reorder,
  expiration,
  lowStock,
  productQuantity,
  inventorySummary,
  movements,
  report,
  medicationUsage,
  offTopic,
  unknown,
}

enum StockQuestionPeriod {
  thisMonth,
  lastMonth,
  lastWeek,
  yesterday,
  last30Days,
  namedMonth,
  unknown,
}

class ParsedStockQuestion {
  const ParsedStockQuestion({
    required this.intent,
    this.category,
    this.product,
    this.productCandidates = const [],
    this.period = StockQuestionPeriod.unknown,
    this.month,
    this.days,
    this.helpMessage,
  });

  final StockQuestionIntent intent;
  final ProductCategory? category;
  final StockProduct? product;
  final List<StockProduct> productCandidates;
  final StockQuestionPeriod period;
  final int? month;
  final int? days;
  final String? helpMessage;

  bool get isAmbiguous => productCandidates.length > 1;
}

abstract interface class QuestionParser {
  ParsedStockQuestion parse(String question, {List<StockProduct> products});
}

class RuleBasedQuestionParser implements QuestionParser {
  const RuleBasedQuestionParser({this.matchTolerance = 2});

  final int matchTolerance;

  @override
  ParsedStockQuestion parse(
    String question, {
    List<StockProduct> products = const [],
  }) {
    final normalized = normalizeFrench(question);
    if (normalized.isEmpty) return _unknown();

    final category = _extractCategory(normalized);
    final period = _extractPeriod(normalized);
    final days = _extractDays(normalized);
    final productMatches = _findProducts(normalized, products);

    if (_containsAny(normalized, stockQuestionConfig.medicationUsage)) {
      return ParsedStockQuestion(
        intent: StockQuestionIntent.medicationUsage,
        category: category,
        product: productMatches.length == 1 ? productMatches.first : null,
        productCandidates: productMatches,
        period: period,
        month: _extractMonth(normalized),
        days: days,
      );
    }

    final intent = _findIntent(normalized);
    if (intent == null) {
      return ParsedStockQuestion(
        intent: _looksOffTopic(normalized)
            ? StockQuestionIntent.offTopic
            : StockQuestionIntent.unknown,
        category: category,
        product: productMatches.length == 1 ? productMatches.first : null,
        productCandidates: productMatches,
        period: period,
        month: _extractMonth(normalized),
        days: days,
        helpMessage: _looksOffTopic(normalized)
            ? 'Je réponds uniquement aux questions sur le stock.'
            : 'Essayez une question sur les alertes, le stock ou les mouvements.',
      );
    }

    return ParsedStockQuestion(
      intent: intent,
      category: category,
      product: productMatches.length == 1 ? productMatches.first : null,
      productCandidates: productMatches,
      period: period,
      month: _extractMonth(normalized),
      days: days,
    );
  }

  StockQuestionIntent? _findIntent(String question) {
    if (_containsAny(
      question,
      stockQuestionConfig.intentKeywords[StockQuestionIntent.lowStock]!,
    )) {
      return StockQuestionIntent.lowStock;
    }
    if (_containsAny(
      question,
      stockQuestionConfig.intentKeywords[StockQuestionIntent.report]!,
    )) {
      return StockQuestionIntent.report;
    }
    for (final entry in stockQuestionConfig.intentKeywords.entries) {
      if (_containsAny(question, entry.value)) return entry.key;
    }
    return null;
  }

  ProductCategory? _extractCategory(String question) {
    for (final entry in stockQuestionConfig.categories.entries) {
      if (_containsAny(question, entry.value)) return entry.key;
    }
    return null;
  }

  List<StockProduct> _findProducts(
    String question,
    List<StockProduct> products,
  ) {
    final words = question.split(' ');
    final candidates = <({StockProduct product, int distance})>[];
    for (final product in products.where((p) => !p.archived)) {
      final name = normalizeFrench(product.name);
      if (question.contains(name)) {
        candidates.add((product: product, distance: 0));
        continue;
      }
      final productWords = name.split(' ');
      var best = name.length;
      for (final word in words) {
        for (final productWord in productWords) {
          final distance =
              word.length >= 4 &&
                  (productWord.startsWith(word) || word.startsWith(productWord))
              ? 0
              : levenshtein(word, productWord);
          best = math.min(best, distance);
        }
      }
      if (best <= matchTolerance) {
        candidates.add((product: product, distance: best));
      }
    }
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    if (candidates.isEmpty) return [];
    final bestDistance = candidates.first.distance;
    return candidates
        .where((candidate) => candidate.distance == bestDistance)
        .map((candidate) => candidate.product)
        .toList();
  }

  StockQuestionPeriod _extractPeriod(String question) {
    if (_containsAny(question, ['ce mois', 'ce mois ci', 'mois actuel'])) {
      return StockQuestionPeriod.thisMonth;
    }
    if (_containsAny(question, ['mois dernier', 'le mois passe'])) {
      return StockQuestionPeriod.lastMonth;
    }
    if (_containsAny(question, ['semaine derniere', 'la semaine passee'])) {
      return StockQuestionPeriod.lastWeek;
    }
    if (_containsAny(question, ['hier'])) return StockQuestionPeriod.yesterday;
    if (_containsAny(question, ['30 derniers jours', 'dernier mois'])) {
      return StockQuestionPeriod.last30Days;
    }
    if (_extractMonth(question) != null) return StockQuestionPeriod.namedMonth;
    return StockQuestionPeriod.unknown;
  }

  int? _extractMonth(String question) {
    for (final entry in stockQuestionConfig.months.entries) {
      if (_containsAny(question, entry.value)) return entry.key;
    }
    return null;
  }

  int? _extractDays(String question) {
    final match = RegExp(
      r'(\d+)\s*(?:(?:derniers?|dernieres?)\s+)?(?:jours?|j)',
    ).firstMatch(question);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  bool _looksOffTopic(String question) {
    return _containsAny(question, stockQuestionConfig.offTopicKeywords);
  }

  bool _containsAny(String text, Iterable<String> values) =>
      values.any((value) => text.contains(normalizeFrench(value)));

  ParsedStockQuestion _unknown() => const ParsedStockQuestion(
    intent: StockQuestionIntent.unknown,
    helpMessage:
        'Écrivez une question sur le stock, les alertes ou les mouvements.',
  );
}

String normalizeFrench(String value) {
  var normalized = value.toLowerCase();
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
  };
  replacements.forEach(
    (from, to) => normalized = normalized.replaceAll(from, to),
  );
  return normalized
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final current = <int>[i + 1];
    for (var j = 0; j < b.length; j++) {
      current.add(
        math.min(
          math.min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + (a[i] == b[j] ? 0 : 1),
        ),
      );
    }
    previous = current;
  }
  return previous.last;
}

class StockQuestionConfig {
  const StockQuestionConfig({
    required this.intentKeywords,
    required this.categories,
    required this.months,
    required this.medicationUsage,
    required this.offTopicKeywords,
  });

  final Map<StockQuestionIntent, List<String>> intentKeywords;
  final Map<ProductCategory, List<String>> categories;
  final Map<int, List<String>> months;
  final List<String> medicationUsage;
  final List<String> offTopicKeywords;
}

const stockQuestionConfig = StockQuestionConfig(
  intentKeywords: {
    StockQuestionIntent.reorder: [
      'reappro',
      'commander',
      'a acheter',
      'besoin achat',
      'besoin d achat',
      'acheter pour',
    ],
    StockQuestionIntent.expiration: [
      'expire',
      'expiration',
      'perime',
      'date limite',
      'dates limites',
    ],
    StockQuestionIntent.lowStock: [
      'stock faible',
      'stocks faibles',
      'sont faibles',
      'niveau bas',
      'niveaux bas',
      'sous le seuil',
      'alerte stock',
      'peu de stock',
    ],
    StockQuestionIntent.inventorySummary: [
      'resume',
      'inventaire',
      'etat du stock',
      'stocks',
      'combien de produits',
    ],
    StockQuestionIntent.productQuantity: [
      'combien',
      'quantite',
      'stock de',
      'stock du',
      'reste t il',
    ],
    StockQuestionIntent.report: ['rapport', 'pertes', 'bilan mensuel'],
    StockQuestionIntent.movements: [
      'mouvement',
      'entrees',
      'sorties',
      'historique',
    ],
  },
  categories: {
    ProductCategory.semences: ['semence', 'graines'],
    ProductCategory.engrais: ['engrais', 'fertilisant'],
    ProductCategory.medicaments: ['medicament', 'medicaments'],
    ProductCategory.traitement: [
      'traitement',
      'fongicide',
      'herbicide',
      'pesticide',
    ],
  },
  months: {
    1: ['janvier'],
    2: ['fevrier'],
    3: ['mars'],
    4: ['avril'],
    5: ['mai'],
    6: ['juin'],
    7: ['juillet'],
    8: ['aout'],
    9: ['septembre'],
    10: ['octobre'],
    11: ['novembre'],
    12: ['decembre'],
  },
  medicationUsage: [
    'dosage',
    'dose',
    'posologie',
    'prescription',
    'utiliser',
    'usage',
  ],
  offTopicKeywords: ['meteo', 'recette', 'football', 'bonjour qui es tu'],
);
