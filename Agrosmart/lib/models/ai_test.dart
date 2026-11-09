import '../services/drone_ai_service.dart';

/// One image of a saved test with its AI result (`null` if not analysed).
class AiTestImage {
  const AiTestImage({required this.image, this.diagnosis});

  final DroneImage image;
  final DiseaseDiagnosis? diagnosis;
}

/// A saved Drone AI test.
class AiTest {
  const AiTest({
    required this.id,
    required this.name,
    required this.date,
    required this.images,
    this.droneId,
    this.droneName,
  });

  final String id;
  final String name;
  final DateTime date;
  final String? droneId;

  /// Kept so the test still shows its drone after the drone is deleted.
  final String? droneName;
  final List<AiTestImage> images;

  int get analysedCount => images.where((i) => i.diagnosis != null).length;

  int get diseasedCount =>
      images.where((i) => i.diagnosis?.best.healthy == false).length;
}

/// `08/11/2026`.
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
