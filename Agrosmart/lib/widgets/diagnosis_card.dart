import 'package:flutter/material.dart';

import '../main.dart';
import '../services/drone_ai_service.dart';

/// One drone image with its AI diagnosis.
class DiagnosisCard extends StatelessWidget {
  const DiagnosisCard({
    super.key,
    required this.index,
    required this.image,
    required this.diagnosis,
  });

  final int index;
  final DroneImage image;

  /// `null` when the image was not analysed.
  final DiseaseDiagnosis? diagnosis;

  @override
  Widget build(BuildContext context) {
    final diagnosis = this.diagnosis;
    final best = diagnosis?.best;
    final color = best == null
        ? mutedGreen
        : best.healthy
        ? freshGreen
        : const Color(0xFFD84315);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borderGreen),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => showImageDialog(context, image),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      image.bytes,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        best == null
                            ? 'Image $index'
                            : 'Image $index · ${best.culture}',
                        style: const TextStyle(color: mutedGreen),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        best == null
                            ? 'Non analysée'
                            : best.healthy
                            ? 'Saine'
                            : best.frenchName,
                        style: TextStyle(
                          color: color,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (best != null)
                        Text(
                          best.disease,
                          style: const TextStyle(
                            color: mutedGreen,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (best != null)
                  Icon(
                    best.healthy
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color: color,
                  ),
              ],
            ),
            if (diagnosis != null && best != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Confiance ${_percent(best.confidence)}',
                    style: const TextStyle(
                      color: inkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (!diagnosis.reliable)
                    const Text(
                      'Peu fiable',
                      style: TextStyle(color: Color(0xFFEF6C00), fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: best.confidence,
                  minHeight: 6,
                  color: color,
                  backgroundColor: borderGreen,
                ),
              ),
              if (best.treatment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  best.healthy ? 'Conseil' : 'Traitement',
                  style: const TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(best.treatment),
              ],
              if (diagnosis.predictions.length > 1) ...[
                const SizedBox(height: 12),
                const Text(
                  'Autres possibilités',
                  style: TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final p in diagnosis.predictions.skip(1))
                  Text(
                    '• ${p.culture} – ${p.healthy ? 'Saine' : p.frenchName} '
                    '(${_percent(p.confidence)})',
                    style: const TextStyle(color: mutedGreen),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)} %';

/// Shows the image full screen, with zoom.
void showImageDialog(BuildContext context, DroneImage image) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(child: Image.memory(image.bytes)),
    ),
  );
}
