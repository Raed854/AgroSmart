import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/irrigation_plan.dart';
import '../models/irrigation_record.dart';
import '../models/parcel_health.dart';
import 'gemini_client.dart';

class IrrigationPlannerException implements Exception {
  const IrrigationPlannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Share of the water that actually reaches the roots.
double methodEfficiency(IrrigationMethod? method) => switch (method) {
  IrrigationMethod.drip => 0.9,
  IrrigationMethod.pivot => 0.8,
  IrrigationMethod.sprinkler => 0.75,
  IrrigationMethod.gravity || IrrigationMethod.manual => 0.6,
  null => 0.75,
};

String _isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Asks Google Gemini for the irrigation planning of a parcel.
class IrrigationPlannerService {
  IrrigationPlannerService({http.Client? client, String? apiKey, String? model})
    : _gemini = GeminiClient(client: client, apiKey: apiKey, model: model);

  final GeminiClient _gemini;

  bool get isConfigured => _gemini.isConfigured;

  static const _systemPrompt = '''
Tu es un agronome expert en irrigation en Tunisie (climat méditerranéen et
semi-aride). On te donne une parcelle (culture, surface), sa méthode
d'irrigation, l'humidité du sol mesurée, l'historique des irrigations et les
prévisions météo journalières (pluie, ET0 FAO-56, températures).

Construis un planning d'irrigation jour par jour pour CHAQUE date demandée.
Méthode :
- ETc = ET0 × Kc (Kc selon la culture et la saison).
- Pluie efficace ≈ 0,8 × pluie prévue.
- Besoin net (mm) = ETc − pluie efficace ; 1 mm sur 1 ha = 10 000 L.
- Quantité brute = besoin net × surface × 10 000 / efficacité de la méthode.
- Ne cumule pas : on irrigue quand la réserve du sol baisse trop (humidité
  < ~35-40 % pour la plupart des cultures), pas forcément tous les jours.
- Si une pluie significative est prévue (≥ 5 mm ou probabilité ≥ 70 %),
  évite d'irriguer la veille et le jour même.
- Utilise "verifier" quand la décision dépend d'une mesure (pluie incertaine,
  humidité inconnue) ; mets alors quantite_litres à null.
- humidite_prevue : humidité du sol estimée en fin de journée (0-100 %).
Arrondis les quantités à la centaine de litres.

Réponds UNIQUEMENT en JSON valide, en français :
{
  "resume": "2 à 3 phrases expliquant la stratégie de la semaine",
  "planning": [
    {"date": "AAAA-MM-JJ", "action": "irriguer|ne_pas_irriguer|verifier",
     "quantite_litres": 2500, "humidite_prevue": 42,
     "raison": "justification courte (météo, humidité)"}
  ],
  "conseils": ["conseil pratique 1", "conseil pratique 2"]
}''';

  Future<IrrigationPlan> generate({
    required Parcel parcel,
    required List<IrrigationRecord> history,
    required List<WeatherDay> weather,
    required double? soilHumidity,
    required String weatherSignature,
    required String humiditySignature,
    DateTime? now,
    int days = 7,
  }) async {
    final today = now ?? DateTime.now();
    final method = history.isEmpty ? null : history.first.method;
    final dates = weather.isNotEmpty
        ? [for (final w in weather) _isoDay(w.date)]
        : [
            for (var i = 0; i < days; i++)
              _isoDay(DateTime(today.year, today.month, today.day + i)),
          ];

    final input = {
      'date_du_jour': _isoDay(today),
      'dates_a_planifier': dates,
      'parcelle': {
        'nom': parcel.name,
        'culture': parcel.cropType,
        'surface_ha': parcel.surfaceHectares,
      },
      'methode_irrigation': method?.label ?? 'inconnue',
      'efficacite_methode': methodEfficiency(method),
      'humidite_sol_mesuree_pct': soilHumidity ?? 'non mesurée',
      'historique_irrigations': [
        for (final r in history.take(10))
          {
            'date': _isoDay(r.date),
            'duree_min': r.durationMinutes,
            'methode': r.method.label,
            'humidite_avant_pct': r.humidityBefore,
            'humidite_apres_pct': r.humidityAfter,
          },
      ],
      'previsions_meteo': weather.isEmpty
          ? 'indisponibles'
          : [for (final w in weather) w.toJson()],
    };

    final Map<String, dynamic> answer;
    try {
      answer = await _gemini.generateJson(
        systemPrompt: _systemPrompt,
        userContent: jsonEncode(input),
      );
    } on GeminiException catch (e) {
      throw IrrigationPlannerException(e.message);
    }

    final IrrigationPlan plan;
    try {
      plan = IrrigationPlan.fromAi(
        answer,
        parcelId: parcel.id,
        generatedAt: today,
        weather: weather,
        soilHumidity: soilHumidity,
        weatherSignature: weatherSignature,
        humiditySignature: humiditySignature,
      );
    } catch (_) {
      throw const IrrigationPlannerException(
        "L'IA a renvoyé une réponse dans un format inattendu.",
      );
    }
    if (plan.days.isEmpty) {
      throw const IrrigationPlannerException("L'IA n'a renvoyé aucun jour.");
    }
    return plan;
  }
}
