import 'package:flutter/material.dart';

import '../../models/parcel_health.dart';
import 'health_palette.dart';

class AnomalyDetailsSheet extends StatelessWidget {
  const AnomalyDetailsSheet({
    super.key,
    required this.anomaly,
    required this.onViewDetails,
  });

  final Anomaly anomaly;
  final VoidCallback onViewDetails;

  static Future<void> show(
    BuildContext context, {
    required Anomaly anomaly,
    required VoidCallback onViewDetails,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        AnomalyDetailsSheet(anomaly: anomaly, onViewDetails: onViewDetails),
  );

  @override
  Widget build(BuildContext context) {
    final color = severityColor(anomaly.severity);
    final confidence = (anomaly.confidence * 100).round();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(anomalyIcon(anomaly.type), color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anomaly.name,
                        style: const TextStyle(
                          color: healthInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        anomaly.type.label,
                        style: const TextStyle(color: healthMuted),
                      ),
                    ],
                  ),
                ),
                _SeverityBadge(severity: anomaly.severity),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'AI confidence',
                  style: TextStyle(
                    color: healthMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$confidence%',
                  style: const TextStyle(
                    color: healthInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: anomaly.confidence,
                minHeight: 8,
                color: healthPrimary,
                backgroundColor: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: healthBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: healthBorder),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: 'Type',
                    value: anomaly.type.label,
                  ),
                  _DetailRow(
                    icon: Icons.priority_high_rounded,
                    label: 'Severity',
                    value: anomaly.severity.label,
                    valueColor: color,
                  ),
                  _DetailRow(
                    icon: Icons.my_location_rounded,
                    label: 'Latitude',
                    value: anomaly.position.latitude.toStringAsFixed(5),
                  ),
                  _DetailRow(
                    icon: Icons.explore_outlined,
                    label: 'Longitude',
                    value: anomaly.position.longitude.toStringAsFixed(5),
                  ),
                  _DetailRow(
                    icon: Icons.event_outlined,
                    label: 'Detected',
                    value: formatDateTime(anomaly.detectedAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: onViewDetails,
                style: FilledButton.styleFrom(
                  backgroundColor: healthPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text(
                  'View Details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final Severity severity;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = healthInk,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: healthPrimary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: healthMuted)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
