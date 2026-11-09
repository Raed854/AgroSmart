import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/drone.dart';

IconData droneTypeIcon(DroneType type) => switch (type) {
  DroneType.multispectral => Icons.filter_vintage_outlined,
  DroneType.thermal => Icons.thermostat_outlined,
  DroneType.spraying => Icons.water_drop_outlined,
  DroneType.mapping => Icons.map_outlined,
};

Color droneStatusColor(DroneStatus status) => switch (status) {
  DroneStatus.active => const Color(0xFF43A047),
  DroneStatus.maintenance => const Color(0xFFF9A825),
  DroneStatus.outOfService => const Color(0xFFE53935),
};

/// The drone photo, or a drone icon when there is none.
class DroneThumbnail extends StatelessWidget {
  const DroneThumbnail({super.key, required this.drone, this.size = 72});

  final Drone drone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFFEAF6E5),
      alignment: Alignment.center,
      child: Icon(Icons.flight_rounded, color: forestGreen, size: size * .45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.square(
        dimension: size,
        child: drone.imagePath == null
            ? placeholder
            : Image.file(
                File(drone.imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class DroneStatusChip extends StatelessWidget {
  const DroneStatusChip({super.key, required this.status});

  final DroneStatus status;

  @override
  Widget build(BuildContext context) {
    final color = droneStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
