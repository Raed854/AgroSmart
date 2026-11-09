import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agriculteur_model.dart';

/// Calls Google's Gemini API to generate a natural-language summary of a
/// farmer's exploitation.
///
/// The API key is never hardcoded: pass it at launch time, e.g.
///   flutter run -d edge --dart-define=GEMINI_API_KEY=your_key
class AiService {
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-flash-latest';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<String> genererSynthese(Agriculteur agriculteur) async {
    if (!isConfigured) {
      throw StateError(
        'No Gemini API key configured. Run with '
        '--dart-define=GEMINI_API_KEY=your_key.',
      );
    }

    final response = await http.post(
      Uri.parse('$_endpoint?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': _buildPrompt(agriculteur)}]},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini request failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts != null && parts.isNotEmpty
        ? parts.first['text'] as String?
        : null;

    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned no text.');
    }
    return text.trim();
  }

  String _buildPrompt(Agriculteur agriculteur) {
    final exploitation = agriculteur.exploitation;
    if (exploitation == null) {
      return 'The farmer ${agriculteur.fullName} has no exploitation '
          'linked yet in a farm management app. Write one short, friendly '
          'sentence (max 30 words, plain text, no markdown) inviting them '
          'to link one to unlock insights.';
    }

    final maintenanceInfo = exploitation.nextMaintenance == null
        ? 'not scheduled'
        : 'in ${exploitation.nextMaintenance!.difference(DateTime.now()).inDays} day(s)';

    return 'You are an assistant inside a farm management app. Write a '
        'short, friendly summary (max 40 words, plain text, no markdown) '
        'for farmer ${agriculteur.fullName} about their exploitation '
        '"${exploitation.name}" (${exploitation.sizeHectares} ha, main '
        'crop: ${exploitation.mainCrop}, located in '
        '${exploitation.location}). Mention anything needing attention: '
        'stock level is ${exploitation.lowStock ? 'low' : 'normal'}, next '
        'maintenance is $maintenanceInfo, production changed by '
        '${exploitation.productionChangePercent}% versus the previous '
        'period.';
  }
}
