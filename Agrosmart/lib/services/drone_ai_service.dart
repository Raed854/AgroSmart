import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Image server that sends the drone pictures (`image/app.py`, port 5002).
///
/// `10.0.2.2` is the PC as seen from the Android emulator. On a real phone,
/// run with `--dart-define=DRONE_IMAGES_URL=http://<PC IP>:5002`.
const droneImagesUrl = String.fromEnvironment(
  'DRONE_IMAGES_URL',
  defaultValue: 'http://10.0.2.2:5002',
);

/// Plant disease AI model (`ai drone/app.py`, port 5001).
///
/// On a real phone: `--dart-define=DRONE_AI_URL=http://<PC IP>:5001`.
const droneAiUrl = String.fromEnvironment(
  'DRONE_AI_URL',
  defaultValue: 'http://10.0.2.2:5001',
);

class DroneAiException implements Exception {
  const DroneAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One picture taken by the drone.
class DroneImage {
  const DroneImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// One class predicted by the AI model.
class DiseasePrediction {
  const DiseasePrediction({
    required this.culture,
    required this.disease,
    required this.frenchName,
    required this.healthy,
    required this.confidence,
    required this.treatment,
  });

  factory DiseasePrediction.fromJson(Map<String, dynamic> json) =>
      DiseasePrediction(
        culture: json['culture'] as String? ?? '',
        disease: json['maladie'] as String? ?? '',
        frenchName: json['nom_fr'] as String? ?? '',
        healthy: json['sain'] as bool? ?? false,
        confidence: (json['confiance'] as num? ?? 0).toDouble(),
        treatment: json['traitement'] as String? ?? '',
      );

  final String culture;
  final String disease;
  final String frenchName;
  final bool healthy;

  /// Between 0 and 1.
  final double confidence;
  final String treatment;
}

/// The AI diagnosis of one image: the best prediction plus the top-k.
class DiseaseDiagnosis {
  const DiseaseDiagnosis({
    required this.best,
    required this.reliable,
    required this.predictions,
    this.raw = const {},
  });

  factory DiseaseDiagnosis.fromJson(Map<String, dynamic> json) =>
      DiseaseDiagnosis(
        best: DiseasePrediction.fromJson(json),
        reliable: json['fiable'] as bool? ?? false,
        predictions: [
          for (final p in json['predictions'] as List<dynamic>? ?? const [])
            DiseasePrediction.fromJson(p as Map<String, dynamic>),
        ],
        raw: json,
      );

  /// The API answer, stored as-is when a test is saved.
  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;

  final DiseasePrediction best;

  /// `false` when the model's confidence is below 60 %.
  final bool reliable;
  final List<DiseasePrediction> predictions;
}

class DroneAiService {
  DroneAiService({
    http.Client? client,
    this.imagesUrl = droneImagesUrl,
    this.aiUrl = droneAiUrl,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String imagesUrl;
  final String aiUrl;

  /// Asks the image server for 3 random drone images.
  Future<List<DroneImage>> fetchImages() async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$imagesUrl/random-images?base64=1'))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw DroneAiException(
        "Serveur d'images injoignable ($imagesUrl). image/app.py est-il lancé ?",
      );
    }
    final body = _decode(response);
    return [
      for (final item in body['images'] as List<dynamic>)
        DroneImage(
          name: item['name'] as String,
          bytes: base64Decode(item['base64'] as String),
        ),
    ];
  }

  /// Sends one image to the AI model and returns its diagnosis.
  Future<DiseaseDiagnosis> diagnose(DroneImage image, {int top = 3}) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$aiUrl/api/diagnostic?top=$top'),
          )
          ..files.add(
            http.MultipartFile.fromBytes(
              'image',
              image.bytes,
              filename: image.name,
            ),
          );
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 60)),
      );
    } catch (_) {
      throw DroneAiException(
        'Modèle AI injoignable ($aiUrl). « ai drone/app.py » est-il lancé ?',
      );
    }
    return DiseaseDiagnosis.fromJson(_decode(response));
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw DroneAiException('Réponse invalide (${response.statusCode}).');
    }
    if (response.statusCode != 200 || body is! Map<String, dynamic>) {
      final message = body is Map ? body['erreur'] ?? body['error'] : null;
      throw DroneAiException(
        message as String? ?? 'Erreur serveur (${response.statusCode}).',
      );
    }
    return body;
  }
}
