import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/network_error.dart';

/// Model used when the configured one is overloaded (HTTP 503) or missing.
const geminiFallbackModel = 'gemini-2.5-flash';

class GeminiException implements Exception {
  const GeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Minimal Google Gemini client (AI Studio `generateContent`) that asks for
/// a JSON answer and returns it decoded.
class GeminiClient {
  GeminiClient({http.Client? client, String? apiKey, String? model})
    : apiKey = apiKey ?? AppConfig.geminiApiKey,
      model = model ?? AppConfig.geminiModel,
      _client = client ?? http.Client();

  final http.Client _client;
  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty;

  static Uri _uri(String model) => Uri.https(
    'generativelanguage.googleapis.com',
    '/v1beta/models/$model:generateContent',
  );

  Future<Map<String, dynamic>> generateJson({
    required String systemPrompt,
    required String userContent,
    double temperature = 0.2,
  }) async {
    if (!isConfigured) {
      throw const GeminiException(
        'Clé Gemini absente : ajoutez GEMINI_API_KEY dans $envAssetPath '
        "puis relancez l'application.",
      );
    }
    final models = {model, geminiFallbackModel}.toList();
    GeminiException? lastError;
    for (final m in models) {
      try {
        return await _call(m, systemPrompt, userContent, temperature);
      } on _Retryable catch (e) {
        lastError = e.error; // Overloaded or unknown model: try the fallback.
      }
    }
    throw lastError!;
  }

  Future<Map<String, dynamic>> _call(
    String model,
    String systemPrompt,
    String userContent,
    double temperature,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _uri(model),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': systemPrompt},
                ],
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': userContent},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': temperature,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw GeminiException(
        "Impossible de joindre l'API Gemini (${describeNetworkError(e)}).",
      );
    }

    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw GeminiException(
        "Réponse illisible de l'API Gemini (${response.statusCode}).",
      );
    }
    if (response.statusCode != 200) {
      final error = body is Map ? body['error'] : null;
      final message = error is Map ? error['message']?.toString() : null;
      final failure = GeminiException(switch (response.statusCode) {
        400 when (message ?? '').contains('API key') => 'Clé Gemini invalide.',
        401 || 403 => 'Clé Gemini invalide ou non autorisée.',
        429 => 'Quota Gemini dépassé. Réessayez dans une minute.',
        503 => 'Gemini est surchargé. Réessayez dans un instant.',
        _ => message ?? 'Erreur API Gemini (${response.statusCode}).',
      });
      if (response.statusCode == 503 || response.statusCode == 404) {
        throw _Retryable(failure);
      }
      throw failure;
    }

    try {
      final candidate = ((body as Map)['candidates'] as List).first as Map;
      final text = [
        for (final part in (candidate['content'] as Map)['parts'] as List)
          (part as Map)['text'] ?? '',
      ].join();
      return jsonDecode(_stripFences(text)) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiException(
        "L'IA a renvoyé une réponse dans un format inattendu.",
      );
    }
  }

  /// Removes ```json fences, in case the model adds them anyway.
  static String _stripFences(String text) {
    final t = text.trim();
    if (!t.startsWith('```')) return t;
    return t
        .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
        .replaceFirst(RegExp(r'```\s*$'), '');
  }
}

class _Retryable implements Exception {
  const _Retryable(this.error);

  final GeminiException error;
}
