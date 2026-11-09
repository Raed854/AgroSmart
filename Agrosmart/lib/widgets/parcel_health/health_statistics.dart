import 'package:flutter/material.dart';

import '../../models/parcel_health.dart';
import 'health_palette.dart';

class HealthStatistics extends StatelessWidget {
  const HealthStatistics({
    super.key,
    required this.healthyPercent,
    required this.warningPercent,
    required this.criticalPercent,
    required this.totalAnomalies,
    required this.visibleAnomalies,
    this.onZoneTap,
    this.onAnomaliesTap,
  });

  final int healthyPercent;
  final int warningPercent;
  final int criticalPercent;
  final int totalAnomalies;

  /// Anomalies matching the active filters.
  final int visibleAnomalies;

  /// Called when a zone card (healthy / warning / critical) is tapped.
  final ValueChanged<ZoneStatus>? onZoneTap;

  /// Called when the "Total anomalies" card is tapped.
  final VoidCallback? onAnomaliesTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _StatCard(
          label: 'Healthy zones',
          value: '$healthyPercent%',
          icon: Icons.check_circle_outline_rounded,
          color: healthyColor,
          progress: healthyPercent / 100,
          onTap: onZoneTap == null
              ? null
              : () => onZoneTap!(ZoneStatus.healthy),
        ),
        _StatCard(
          label: 'Warning zones',
          value: '$warningPercent%',
          icon: Icons.warning_amber_rounded,
          color: warningColor,
          progress: warningPercent / 100,
          onTap: onZoneTap == null
              ? null
              : () => onZoneTap!(ZoneStatus.warning),
        ),
        _StatCard(
          label: 'Critical zones',
          value: '$criticalPercent%',
          icon: Icons.error_outline_rounded,
          color: criticalColor,
          progress: criticalPercent / 100,
          onTap: onZoneTap == null
              ? null
              : () => onZoneTap!(ZoneStatus.critical),
        ),
        _StatCard(
          label: 'Total anomalies',
          value: '$totalAnomalies',
          icon: Icons.gps_fixed_rounded,
          color: healthPrimary,
          footer: visibleAnomalies == totalAnomalies
              ? 'All shown on map'
              : '$visibleAnomalies shown with filters',
          onTap: onAnomaliesTap,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.progress,
    this.footer,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;
  final String? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: healthCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: _content()),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: healthMuted,
                size: 18,
              ),
            ],
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: healthInk,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          label,
          style: const TextStyle(
            color: healthMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (progress != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: .14),
            ),
          )
        else if (footer != null)
          Text(
            footer!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
