import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const _earthRadiusMeters = 6371008.8;

LatLng polygonCentroid(List<LatLng> points) => LatLng(
  points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
  points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
);

/// Orders corners clockwise around their centre so the polygon never
/// crosses itself, whatever order the farmer entered the points in.
List<LatLng> orderPolygon(List<LatLng> points) {
  if (points.length < 3) return List.of(points);
  final centre = polygonCentroid(points);
  double angle(LatLng p) =>
      math.atan2(p.latitude - centre.latitude, p.longitude - centre.longitude);
  return List.of(points)..sort((a, b) => angle(b).compareTo(angle(a)));
}

/// Area of a small polygon in hectares (local flat-earth projection).
double polygonAreaHectares(List<LatLng> points) {
  if (points.length < 3) return 0;
  final lat0 = polygonCentroid(points).latitudeInRad;
  final projected = [
    for (final p in points)
      (
        x: _earthRadiusMeters * p.longitudeInRad * math.cos(lat0),
        y: _earthRadiusMeters * p.latitudeInRad,
      ),
  ];
  var twiceArea = 0.0;
  for (var i = 0; i < projected.length; i++) {
    final a = projected[i];
    final b = projected[(i + 1) % projected.length];
    twiceArea += a.x * b.y - b.x * a.y;
  }
  return twiceArea.abs() / 2 / 10000;
}

/// Whether [point] lies inside [polygon] (ray casting).
bool pointInPolygon(LatLng point, List<LatLng> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i];
    final b = polygon[j];
    if ((a.latitude > point.latitude) != (b.latitude > point.latitude) &&
        point.longitude <
            (b.longitude - a.longitude) *
                    (point.latitude - a.latitude) /
                    (b.latitude - a.latitude) +
                a.longitude) {
      inside = !inside;
    }
  }
  return inside;
}
