import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/parcel_health.dart';
import '../utils/geo_utils.dart';
import '../widgets/parcel_health/health_palette.dart';
import 'anomaly_detail_screen.dart';

/// Detail of one health statistic: the zones of a status (with their
/// coordinates and the anomalies inside them) or the list of all anomalies
/// with their coordinates.
class StatisticDetailScreen extends StatelessWidget {
  /// Shows the zones of [status].
  const StatisticDetailScreen.zones({
    super.key,
    required ZoneStatus this.status,
    required this.analysis,
    required this.parcelName,
  });

  /// Shows every anomaly of the analysis.
  const StatisticDetailScreen.anomalies({
    super.key,
    required this.analysis,
    required this.parcelName,
  }) : status = null;

  final ZoneStatus? status;
  final MissionAnalysis analysis;
  final String parcelName;

  static String formatPoint(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';

  String get _title => switch (status) {
    ZoneStatus.healthy => 'Healthy zones',
    ZoneStatus.warning => 'Warning zones',
    ZoneStatus.critical => 'Critical zones',
    null => 'All anomalies',
  };

  Color get _color => status == null ? healthPrimary : zoneColor(status!);

  List<HealthZone> get _zones =>
      analysis.zones.where((z) => z.status == status).toList();

  List<Anomaly> _anomaliesIn(HealthZone zone) => analysis.anomalies
      .where((a) => pointInPolygon(a.position, zone.points))
      .toList();

  /// CSV of every coordinate shown on this screen.
  String _exportCsv() {
    final buffer = StringBuffer();
    if (status == null) {
      buffer.writeln(
        'id,name,type,severity,confidence,latitude,longitude,detected_at',
      );
      for (final a in analysis.anomalies) {
        buffer.writeln(
          '${a.id},"${a.name}",${a.type.apiValue},${a.severity.apiValue},'
          '${a.confidence.toStringAsFixed(2)},${a.position.latitude},'
          '${a.position.longitude},${a.detectedAt.toIso8601String()}',
        );
      }
    } else {
      buffer.writeln('zone,point,latitude,longitude');
      final zones = _zones;
      for (var z = 0; z < zones.length; z++) {
        final points = zones[z].points;
        for (var i = 0; i < points.length; i++) {
          buffer.writeln(
            '${z + 1},${i + 1},${points[i].latitude},${points[i].longitude}',
          );
        }
      }
    }
    return buffer.toString();
  }

  Future<void> _copy(BuildContext context, String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAnomaly(BuildContext context, Anomaly anomaly) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          AnomalyDetailScreen(anomaly: anomaly, parcelName: parcelName),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isAnomalies = status == null;
    final zones = _zones;
    final isEmpty = isAnomalies ? analysis.anomalies.isEmpty : zones.isEmpty;

    return Scaffold(
      backgroundColor: healthBackground,
      appBar: AppBar(
        backgroundColor: healthBackground,
        foregroundColor: healthInk,
        elevation: 0,
        title: Text(
          _title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!isEmpty)
            IconButton(
              tooltip: 'Export coordinates (CSV)',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () =>
                  _copy(context, _exportCsv(), 'Coordinates (CSV)'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _SummaryCard(
            color: _color,
            parcelName: parcelName,
            title: _title,
            value: switch (status) {
              ZoneStatus.healthy => '${analysis.healthyPercent}%',
              ZoneStatus.warning => '${analysis.warningPercent}%',
              ZoneStatus.critical => '${analysis.criticalPercent}%',
              null => '${analysis.anomalies.length}',
            },
            subtitle: isAnomalies
                ? _severityBreakdown()
                : '${zones.length} zone(s) • '
                      '${zones.fold<double>(0, (s, z) => s + polygonAreaHectares(z.points)).toStringAsFixed(2)} ha',
          ),
          const SizedBox(height: 16),
          if (isEmpty)
            _Empty(isAnomalies: isAnomalies)
          else if (isAnomalies)
            for (final a in analysis.anomalies)
              _AnomalyTile(
                anomaly: a,
                onTap: () => _openAnomaly(context, a),
                onCopy: () =>
                    _copy(context, formatPoint(a.position), 'Coordinates'),
              )
          else
            for (var i = 0; i < zones.length; i++)
              _ZoneCard(
                index: i + 1,
                zone: zones[i],
                color: _color,
                anomalies: _anomaliesIn(zones[i]),
                onAnomalyTap: (a) => _openAnomaly(context, a),
                onCopy: (text) => _copy(context, text, 'Coordinates'),
              ),
        ],
      ),
    );
  }

  String _severityBreakdown() {
    final parts = [
      for (final s in Severity.values)
        if (analysis.anomalies.any((a) => a.severity == s))
          '${analysis.anomalies.where((a) => a.severity == s).length} ${s.label.toLowerCase()}',
    ];
    return parts.isEmpty ? 'No anomaly detected' : parts.join(' • ');
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.color,
    required this.parcelName,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final Color color;
  final String parcelName;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: healthCardDecoration(),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parcelName,
                style: const TextStyle(color: healthMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: healthInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: healthMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.index,
    required this.zone,
    required this.color,
    required this.anomalies,
    required this.onAnomalyTap,
    required this.onCopy,
  });

  final int index;
  final HealthZone zone;
  final Color color;
  final List<Anomaly> anomalies;
  final ValueChanged<Anomaly> onAnomalyTap;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final centroid = polygonCentroid(zone.points);
    final allPoints = [
      for (var i = 0; i < zone.points.length; i++)
        'P${i + 1}: ${StatisticDetailScreen.formatPoint(zone.points[i])}',
    ].join('\n');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: healthCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.crop_square_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Zone $index',
                  style: const TextStyle(
                    color: healthInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${polygonAreaHectares(zone.points).toStringAsFixed(2)} ha',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              IconButton(
                tooltip: 'Copy coordinates',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () => onCopy(allPoints),
              ),
            ],
          ),
          _CoordRow(
            label: 'Centre',
            value: StatisticDetailScreen.formatPoint(centroid),
            bold: true,
          ),
          const Divider(height: 18, color: healthBorder),
          for (var i = 0; i < zone.points.length; i++)
            _CoordRow(
              label: 'P${i + 1}',
              value: StatisticDetailScreen.formatPoint(zone.points[i]),
            ),
          const SizedBox(height: 10),
          Text(
            anomalies.isEmpty
                ? 'No anomaly in this zone'
                : '${anomalies.length} anomaly(ies) in this zone',
            style: const TextStyle(
              color: healthInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          for (final a in anomalies)
            _AnomalyTile(anomaly: a, dense: true, onTap: () => onAnomalyTap(a)),
        ],
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  const _CoordRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(color: healthMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              color: healthInk,
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AnomalyTile extends StatelessWidget {
  const _AnomalyTile({
    required this.anomaly,
    required this.onTap,
    this.onCopy,
    this.dense = false,
  });

  final Anomaly anomaly;
  final VoidCallback onTap;
  final VoidCallback? onCopy;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(anomaly.severity);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(anomalyIcon(anomaly.type), color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                anomaly.name,
                style: const TextStyle(
                  color: healthInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${anomaly.type.label} • ${anomaly.severity.label} • '
                '${(anomaly.confidence * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: healthMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      StatisticDetailScreen.formatPoint(anomaly.position),
                      style: const TextStyle(
                        color: healthInk,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              if (!dense) ...[
                const SizedBox(height: 2),
                Text(
                  formatDateTime(anomaly.detectedAt),
                  style: const TextStyle(color: healthMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            tooltip: 'Copy coordinates',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: onCopy,
          ),
        const Icon(Icons.chevron_right_rounded, color: healthMuted),
      ],
    );

    if (dense) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: content,
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: healthCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: content),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.isAnomalies});

  final bool isAnomalies;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: healthCardDecoration(),
    child: Text(
      isAnomalies
          ? 'No anomaly detected for this mission.'
          : 'No zone with this status for this mission.',
      textAlign: TextAlign.center,
      style: const TextStyle(color: healthMuted),
    ),
  );
}
