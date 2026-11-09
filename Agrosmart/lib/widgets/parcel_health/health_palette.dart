import 'package:flutter/material.dart';

import '../../models/parcel_health.dart';

const healthPrimary = Color(0xFF2E7D32);
const healthSecondary = Color(0xFF81C784);
const healthBackground = Color(0xFFF8FAF8);
const healthInk = Color(0xFF1C2B1E);
const healthMuted = Color(0xFF6B7A6E);
const healthBorder = Color(0xFFE3EAE3);

const healthyColor = Color(0xFF43A047);
const warningColor = Color(0xFFF9A825);
const criticalColor = Color(0xFFE53935);

const healthCardShadow = [
  BoxShadow(color: Color(0x0F1B5E20), blurRadius: 18, offset: Offset(0, 6)),
];

BoxDecoration healthCardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: healthBorder),
  boxShadow: healthCardShadow,
);

Color zoneColor(ZoneStatus status) => switch (status) {
  ZoneStatus.healthy => healthyColor,
  ZoneStatus.warning => warningColor,
  ZoneStatus.critical => criticalColor,
};

Color severityColor(Severity severity) => switch (severity) {
  Severity.low => const Color(0xFF7CB342),
  Severity.medium => warningColor,
  Severity.high => const Color(0xFFEF6C00),
  Severity.critical => criticalColor,
};

IconData anomalyIcon(AnomalyType type) => switch (type) {
  AnomalyType.disease => Icons.coronavirus_outlined,
  AnomalyType.waterStress => Icons.water_drop_outlined,
  AnomalyType.weed => Icons.grass_rounded,
  AnomalyType.growth => Icons.trending_down_rounded,
};

String _two(int value) => value.toString().padLeft(2, '0');

String formatDate(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';

String formatDateTime(DateTime date) =>
    '${formatDate(date)} • ${_two(date.hour)}:${_two(date.minute)}';
