import 'dart:convert';

import 'package:http/http.dart' as http;

import 'equipment_analytics.dart';
import 'gemini_client.dart';

class AiAnalyticsException implements Exception {
  const AiAnalyticsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A maintenance the AI advises to plan.
class AiMaintenance {
  const AiMaintenance({
    required this.equipment,
    required this.date,
    required this.priority,
    required this.reason,
  });

  factory AiMaintenance.fromJson(Map<String, dynamic> json) => AiMaintenance(
    equipment: json['materiel']?.toString() ?? '',
    date: DateTime.tryParse(json['date_prevue']?.toString() ?? ''),
    priority: json['priorite']?.toString() ?? 'moyenne',
    reason: json['raison']?.toString() ?? '',
  );

  final String equipment;
  final DateTime? date;

  /// `haute`, `moyenne` or `faible`.
  final String priority;
  final String reason;
}

/// The AI's lifespan estimate for one equipment.
class AiLifespan {
  const AiLifespan({
    required this.equipment,
    required this.remainingYears,
    required this.comment,
  });

  factory AiLifespan.fromJson(Map<String, dynamic> json) => AiLifespan(
    equipment: json['materiel']?.toString() ?? '',
    remainingYears: (json['annees_restantes'] as num?)?.toDouble(),
    comment: json['commentaire']?.toString() ?? '',
  );

  final String equipment;
  final double? remainingYears;
  final String comment;
}

/// Analysis of the fleet written by the AI, in French.
class AiFleetReport {
  const AiFleetReport({
    required this.summary,
    required this.consumption,
    required this.maintenances,
    required this.lifespans,
    required this.recommendations,
  });

  factory AiFleetReport.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final item in json[key] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) parse(item),
    ];
    List<String> strings(String key) => [
      for (final item in json[key] as List<dynamic>? ?? const [])
        item.toString(),
    ];
    return AiFleetReport(
      summary: json['resume']?.toString() ?? '',
      consumption: strings('consommation'),
      maintenances: list('maintenances', AiMaintenance.fromJson),
      lifespans: list('duree_vie', AiLifespan.fromJson),
      recommendations: strings('recommandations'),
    );
  }

  final String summary;
  final List<String> consumption;
  final List<AiMaintenance> maintenances;
  final List<AiLifespan> lifespans;
  final List<String> recommendations;
}

/// Sends the computed statistics to Google Gemini and returns its analysis.
class AiAnalyticsService {
  AiAnalyticsService({http.Client? client, String? apiKey, String? model})
    : _gemini = GeminiClient(client: client, apiKey: apiKey, model: model);

  final GeminiClient _gemini;

  bool get isConfigured => _gemini.isConfigured;

  static const _systemPrompt = '''
Tu es un expert en machinisme agricole et en gestion de flotte en Tunisie.
On te donne les statistiques d'un parc de matériels agricoles (carburant,
maintenance, main d'œuvre, âge, état). Les montants sont en dinars tunisiens.
Analyse les consommations de carburant (anomalies, hausses, matériels les plus
gourmands), prévois les prochaines maintenances et estime la durée de vie
restante de chaque matériel. Base-toi sur les chiffres fournis ; quand ils
manquent, dis-le et donne une estimation prudente.

Réponds UNIQUEMENT en JSON valide, en français, avec ce format :
{
  "resume": "2 à 4 phrases sur l'état général du parc",
  "consommation": ["constat 1", "constat 2"],
  "maintenances": [
    {"materiel": "nom exact", "date_prevue": "AAAA-MM-JJ",
     "priorite": "haute|moyenne|faible", "raison": "pourquoi"}
  ],
  "duree_vie": [
    {"materiel": "nom exact", "annees_restantes": 3.5,
     "commentaire": "justification courte"}
  ],
  "recommandations": ["action concrète 1", "action concrète 2"]
}''';

  Future<AiFleetReport> analyse(FleetAnalytics analytics) async {
    final Map<String, dynamic> json;
    try {
      json = await _gemini.generateJson(
        systemPrompt: _systemPrompt,
        userContent: jsonEncode(analytics.toAiJson()),
        temperature: 0.3,
      );
    } on GeminiException catch (e) {
      throw AiAnalyticsException(e.message);
    }
    return AiFleetReport.fromJson(json);
  }
}
