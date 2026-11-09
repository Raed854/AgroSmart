import 'package:flutter/material.dart';

import '../../models/parcel_health.dart';
import 'health_palette.dart';

class ParcelInfoCard extends StatelessWidget {
  const ParcelInfoCard({
    super.key,
    required this.parcel,
    required this.mission,
    required this.overallHealth,
    this.onEdit,
  });

  final Parcel parcel;
  final DroneMission? mission;

  /// `null` when the parcel has no analysed drone mission yet.
  final int? overallHealth;

  /// Opens the corner-point editor for this parcel.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final health = overallHealth;
    final healthColor = health == null
        ? healthBorder
        : health >= 75
        ? healthyColor
        : health >= 50
        ? warningColor
        : criticalColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [healthPrimary, Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E7D32),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: _CropChip(cropType: parcel.cropType)),
                    if (onEdit != null) ...[
                      const SizedBox(width: 6),
                      _EditButton(onTap: onEdit!),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  parcel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoLine(
                  icon: Icons.straighten_rounded,
                  text: '${parcel.surfaceHectares} hectares',
                ),
                const SizedBox(height: 6),
                _InfoLine(
                  icon: Icons.flight_takeoff_rounded,
                  text: mission == null
                      ? 'No drone mission yet'
                      : 'Last mission: ${formatDate(mission!.flownAt)}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HealthRing(value: health, color: healthColor),
        ],
      ),
    );
  }
}

class _CropChip extends StatelessWidget {
  const _CropChip({required this.cropType});

  final String cropType;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.eco_rounded, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            cropType,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Edit parcel corners',
    child: Material(
      color: Colors.white.withValues(alpha: .18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.edit_location_alt_outlined,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: Colors.white70),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    ],
  );
}

class _HealthRing extends StatelessWidget {
  const _HealthRing({required this.value, required this.color});

  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (value ?? 0) / 100),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0xFFE8F5E9),
              valueColor: AlwaysStoppedAnimation(color),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value == null ? '--' : '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: healthInk,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Health',
                    style: TextStyle(color: healthMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
