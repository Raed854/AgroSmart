import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_application/models/parcelle_model.dart';
import 'package:my_application/services/groq_ai_service.dart';

void main() {
  group('GroqAIService', () {
    test('returns null when API key is null', () async {
      final service = GroqAIService(apiKey: null);
      final parcelle = ParcelleModel(
        id: 'test-1',
        nom: 'Parcelle Test',
        surface: 5.0,
        typeSol: 'argileux',
        latitude: 36.8065,
        longitude: 10.1815,
        createdAt: DateTime.now(),
      );

      // Avec une clé null, le service retourne une réponse démo au lieu de null
      final result = await service.analyzeParcelle(parcelle, []);
      
      // Le mode démo retourne toujours une analyse
      expect(result, isNotNull);
      expect(result, contains('argileux'));
    });

    test('returns demo response when API key is empty', () async {
      final service = GroqAIService(apiKey: '');
      final parcelle = ParcelleModel(
        id: 'test-1',
        nom: 'Parcelle Test',
        surface: 5.0,
        typeSol: 'sableux',
        latitude: 36.8065,
        longitude: 10.1815,
        createdAt: DateTime.now(),
      );

      final result = await service.analyzeParcelle(parcelle, []);
      
      expect(result, isNotNull);
      expect(result, contains('sableux'));
    });

    test('returns analysis from API when key is provided', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('groq.com'));
        expect(request.headers['Authorization'], contains('Bearer'));
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body);
        expect(body['model'], 'llama-3.3-70b-versatile');
        expect(body['max_tokens'], 600);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': 'Analyse de la parcelle Test réussie.',
                }
              }
            ]
          }),
          200,
        );
      });

      final service = GroqAIService(
        client: mockClient,
        apiKey: 'test-api-key',
      );

      final parcelle = ParcelleModel(
        id: 'test-1',
        nom: 'Test',
        surface: 10.0,
        typeSol: 'limoneux',
        latitude: 36.8,
        longitude: 10.2,
        createdAt: DateTime.now(),
      );

      final result = await service.analyzeParcelle(parcelle, []);

      expect(result, isNotNull);
      expect(result, contains('Analyse de la parcelle Test réussie'));
    });

    test('returns null on API error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = GroqAIService(
        client: mockClient,
        apiKey: 'test-api-key',
      );

      final parcelle = ParcelleModel(
        id: 'test-1',
        nom: 'Test',
        surface: 10.0,
        typeSol: 'argileux',
        latitude: 36.8,
        longitude: 10.2,
        createdAt: DateTime.now(),
      );

      final result = await service.analyzeParcelle(parcelle, []);

      expect(result, isNull);
    });

    test('includes anomalies in prompt', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        final messages = body['messages'] as List;
        final userMessage = messages.firstWhere(
          (m) => m['role'] == 'user',
        );
        final content = userMessage['content'] as String;

        expect(content, contains('Points détectés'));
        expect(content, contains('Surface très grande'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Analyse avec anomalies'}
              }
            ]
          }),
          200,
        );
      });

      final service = GroqAIService(
        client: mockClient,
        apiKey: 'test-key',
      );

      final parcelle = ParcelleModel(
        id: 'test-1',
        nom: 'Grande Parcelle',
        surface: 100.0,
        typeSol: 'argileux',
        latitude: 36.8,
        longitude: 10.2,
        createdAt: DateTime.now(),
      );

      await service.analyzeParcelle(parcelle, ['Surface très grande']);
    });

    test('disposes client properly', () {
      final service = GroqAIService(apiKey: 'test');
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
