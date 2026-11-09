import 'package:flutter/material.dart';

import '../models/parcel_health.dart';
import '../widgets/parcel_health/health_palette.dart';

class AnomalyDetailScreen extends StatelessWidget {
  const AnomalyDetailScreen({
    super.key,
    required this.anomaly,
    required this.parcelName,
  });

  final Anomaly anomaly;
  final String parcelName;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(anomaly.severity);

    Widget section(String title, IconData icon, String body) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: healthCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: healthPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: healthInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(color: healthMuted, height: 1.5)),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: healthBackground,
      appBar: AppBar(
        backgroundColor: healthBackground,
        foregroundColor: healthInk,
        elevation: 0,
        title: const Text(
          'Anomaly details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: .4)),
            ),
            child: Row(
              children: [
                Icon(anomalyIcon(anomaly.type), color: color, size: 36),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      Text(
                        '$parcelName • ${anomaly.type.label} • '
                        '${anomaly.severity.label}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          section(
            'AI observation',
            Icons.auto_awesome_outlined,
            anomaly.description,
          ),
          section(
            'Recommended action',
            Icons.task_alt_rounded,
            anomaly.recommendation,
          ),
          section(
            'Detection',
            Icons.satellite_alt_outlined,
            'Detected ${formatDateTime(anomaly.detectedAt)} with '
                '${(anomaly.confidence * 100).round()}% model confidence.\n'
                'GPS: ${anomaly.position.latitude.toStringAsFixed(5)}, '
                '${anomaly.position.longitude.toStringAsFixed(5)}',
          ),
        ],
      ),
    );
  }
}
