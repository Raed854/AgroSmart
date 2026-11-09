import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/parcelle_model.dart';

/// Service pour l'intégration de l'API Groq (optionnel)
/// Fournit une analyse détaillée via Groq AI si disponible
/// API Key gratuite disponible sur: https://console.groq.com
class GroqAIService {
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';
  static const int _maxTokens = 600;
  static const Duration _timeout = Duration(seconds: 15);

  static const String _systemPrompt = '''Tu es un assistant agricole pour la Tunisie. 
Donne des suggestions de cultures et des conseils courts. 
Présente les risques comme des points à vérifier, jamais comme des diagnostics confirmés. 
Réponds en 5 lignes maximum.''';

  final http.Client _client;
  final String? _apiKey;

  GroqAIService({http.Client? client, String? apiKey}) 
      : _client = client ?? http.Client(),
        _apiKey = apiKey;

  /// Analyse une parcelle avec Groq AI
  /// Retourne l'analyse en texte ou null en cas d'erreur
  Future<String?> analyzeParcelle(
    ParcelleModel parcelle,
    List<String> ruleBasedAnomalies,
  ) async {
    try {
      // Si aucune clé API fournie, mode démo avec réponse simulée
      if (_apiKey == null || _apiKey.isEmpty) {
        print('DEBUG Groq: No API key, using demo mode');
        return _getDemoResponse(parcelle, ruleBasedAnomalies);
      }

      print('DEBUG Groq: Making API call to $_apiUrl');
      final userPrompt = _buildPrompt(parcelle, ruleBasedAnomalies);
      print('DEBUG Groq: Prompt length: ${userPrompt.length} chars');

      final response = await _client
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
              'max_tokens': _maxTokens,
              'temperature': 0.7,
            }),
          )
          .timeout(_timeout);

      print('DEBUG Groq: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        
        if (choices != null && choices.isNotEmpty) {
          final firstChoice = choices[0] as Map<String, dynamic>;
          final message = firstChoice['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.length > 50) {
            print('DEBUG Groq: Got content: ${content.substring(0, 50)}...');
          } else {
            print('DEBUG Groq: Got content: $content');
          }
          return content;
        }
      } else {
        print('DEBUG Groq: API error - Status ${response.statusCode}, falling back to demo');
      }

      // Fallback to demo if API didn't return valid response
      return _getDemoResponse(parcelle, ruleBasedAnomalies);
    } on TimeoutException catch (e) {
      print('DEBUG Groq: Timeout after 15s - $e, using demo mode');
      return _getDemoResponse(parcelle, ruleBasedAnomalies);
    } catch (e) {
      print('DEBUG Groq: Exception occurred - $e, using demo mode');
      return _getDemoResponse(parcelle, ruleBasedAnomalies);
    }
  }

  String _buildPrompt(
    ParcelleModel parcelle,
    List<String> ruleBasedAnomalies,
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('Analyse cette parcelle agricole en Tunisie :');
    buffer.writeln('');
    buffer.writeln('Nom : ${parcelle.nom}');
    buffer.writeln('Surface : ${parcelle.surface.toStringAsFixed(1)} ha');
    buffer.writeln('Type de sol : ${parcelle.typeSol}');
    buffer.writeln(
      'Position GPS : ${parcelle.latitude.toStringAsFixed(6)}, ${parcelle.longitude.toStringAsFixed(6)}',
    );

    if (ruleBasedAnomalies.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Points détectés par l\'analyse automatique :');
      for (final anomaly in ruleBasedAnomalies) {
        buffer.writeln('- $anomaly');
      }
    }

    buffer.writeln('');
    buffer.writeln(
      'Donne des suggestions de cultures adaptées et des conseils pratiques.',
    );

    return buffer.toString();
  }

  /// Réponse démo pour tester l'interface sans API
  String _getDemoResponse(ParcelleModel parcelle, List<String> anomalies) {
    final soilType = parcelle.typeSol.toLowerCase();
    
    if (soilType.contains('argileux')) {
      return '''Pour ce sol argileux de ${parcelle.surface.toStringAsFixed(1)} ha, privilégiez le blé dur, le tournesol ou les légumineuses. 
Vérifiez le drainage pour éviter l'engorgement en période pluvieuse. 
Envisagez un apport en matière organique pour améliorer la structure du sol.''';
    } else if (soilType.contains('sableux')) {
      return '''Ce sol sableux convient bien aux cultures comme la pastèque, le melon ou les pommes de terre. 
L'irrigation goutte-à-goutte est recommandée pour économiser l'eau. 
Surveillez les apports en nutriments car le sol retient peu les éléments.''';
    } else if (soilType.contains('limoneux')) {
      return '''Le sol limoneux de cette parcelle est excellent pour les céréales et les cultures maraîchères. 
Tomates, poivrons et aubergines donneront de bons rendements. 
Attention au compactage : évitez le travail du sol en conditions humides.''';
    } else if (soilType.contains('calcaire')) {
      return '''Sol calcaire adapté aux oliviers, amandiers et vignes. 
Pour les cultures annuelles, surveillez le pH et les carences en fer. 
Les légumineuses comme les pois chiches s'adaptent bien à ce type de sol.''';
    } else {
      return '''Pour cette parcelle de ${parcelle.surface.toStringAsFixed(1)} ha, plusieurs options sont possibles selon vos objectifs. 
Les cultures céréalières restent une valeur sûre en Tunisie. 
Consultez un agronome local pour une analyse détaillée du sol et un plan de rotation optimal.''';
    }
  }

  void dispose() {
    _client.close();
  }
}
