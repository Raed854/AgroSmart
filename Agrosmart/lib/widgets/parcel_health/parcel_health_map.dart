import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/parcel_health.dart';
import '../../services/location_service.dart';
import 'health_palette.dart';
import 'user_location_marker.dart';

class ParcelHealthMap extends StatefulWidget {
  const ParcelHealthMap({
    super.key,
    required this.parcel,
    required this.zones,
    required this.anomalies,
    required this.selectedAnomaly,
    required this.onAnomalyTap,
    required this.onMapTap,
    this.onInteractionChanged,
    this.isLoading = false,
    this.height = 360,
    this.locationService = const LocationService(),
  });

  final Parcel parcel;
  final List<HealthZone> zones;
  final List<Anomaly> anomalies;
  final Anomaly? selectedAnomaly;
  final ValueChanged<Anomaly> onAnomalyTap;
  final VoidCallback onMapTap;

  /// Reports when the farmer touches the map, so a parent scroll view can
  /// stop scrolling and let the map pan.
  final ValueChanged<bool>? onInteractionChanged;
  final bool isLoading;
  final double height;
  final LocationService locationService;

  @override
  State<ParcelHealthMap> createState() => _ParcelHealthMapState();
}

class _ParcelHealthMapState extends State<ParcelHealthMap> {
  static const _pinSize = 44.0;

  final _mapController = MapController();
  int _activePointers = 0;
  LatLng? _myPosition;
  bool _locating = false;

  CameraFit get _parcelFit => CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(widget.parcel.boundary),
    padding: const EdgeInsets.fromLTRB(32, 48, 32, 64),
  );

  @override
  void didUpdateWidget(covariant ParcelHealthMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parcel.id != widget.parcel.id ||
        !listEquals(oldWidget.parcel.boundary, widget.parcel.boundary)) {
      _mapController.fitCamera(_parcelFit);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  Future<void> _showMyPosition() async {
    setState(() => _locating = true);
    try {
      final position = await widget.locationService.currentPosition();
      if (!mounted) return;
      setState(() => _myPosition = position);
      _mapController.move(position, 17);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is LocationException ? e.message : 'Unable to get your position.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _updatePointers(int delta) {
    final wasActive = _activePointers > 0;
    _activePointers = (_activePointers + delta).clamp(0, 10);
    final isActive = _activePointers > 0;
    if (wasActive != isActive) widget.onInteractionChanged?.call(isActive);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedAnomaly;

    return Container(
      height: widget.height,
      decoration: healthCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Listener(
        onPointerDown: (_) => _updatePointers(1),
        onPointerUp: (_) => _updatePointers(-1),
        onPointerCancel: (_) => _updatePointers(-1),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: _parcelFit,
                minZoom: 13,
                maxZoom: 20,
                backgroundColor: const Color(0xFFE8EFE8),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, _) => widget.onMapTap(),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.my_application',
                  maxNativeZoom: 19,
                ),
                PolygonLayer(
                  polygons: [
                    for (final zone in widget.zones)
                      Polygon(
                        points: zone.points,
                        color: zoneColor(zone.status).withValues(
                          alpha: zone.status == ZoneStatus.healthy ? .28 : .5,
                        ),
                        borderColor: zoneColor(zone.status),
                        borderStrokeWidth: zone.status == ZoneStatus.healthy
                            ? 0
                            : 1.5,
                      ),
                    Polygon(
                      points: widget.parcel.boundary,
                      color: Colors.transparent,
                      borderColor: healthPrimary,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (_myPosition != null) userLocationMarker(_myPosition!),
                    for (final anomaly in widget.anomalies)
                      Marker(
                        key: ValueKey(anomaly.id),
                        point: anomaly.position,
                        width: _pinSize,
                        height: _pinSize,
                        alignment: Alignment.topCenter,
                        child: _AnomalyPin(
                          anomaly: anomaly,
                          isSelected: anomaly.id == selected?.id,
                          onTap: () => widget.onAnomalyTap(anomaly),
                        ),
                      ),
                    if (selected != null)
                      Marker(
                        point: selected.position,
                        width: 210,
                        height: 72 + _pinSize + 6,
                        alignment: Alignment.topCenter,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _AnomalyPopup(
                            anomaly: selected,
                            onTap: () => widget.onAnomalyTap(selected),
                          ),
                        ),
                      ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
            if (widget.isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: healthPrimary,
                  backgroundColor: Color(0x3381C784),
                ),
              ),
            const Positioned(left: 12, top: 12, child: _MapLegend()),
            Positioned(
              right: 12,
              top: 12,
              child: Column(
                children: [
                  MapControlButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom in',
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  MapControlButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom out',
                    onTap: () => _zoomBy(-1),
                  ),
                  const SizedBox(height: 8),
                  MapControlButton(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: 'Recenter on parcel',
                    onTap: () => _mapController.fitCamera(_parcelFit),
                  ),
                  const SizedBox(height: 8),
                  MapControlButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Show my position',
                    color: userLocationColor,
                    isBusy: _locating,
                    onTap: _showMyPosition,
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

class _AnomalyPin extends StatelessWidget {
  const _AnomalyPin({
    required this.anomaly,
    required this.isSelected,
    required this.onTap,
  });

  final Anomaly anomaly;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(anomaly.severity);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.2 : 1,
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 180),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(
              Icons.location_on,
              size: 44,
              color: color,
              shadows: const [Shadow(color: Colors.black38, blurRadius: 6)],
            ),
            Positioned(
              top: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(anomalyIcon(anomaly.type), size: 13, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyPopup extends StatelessWidget {
  const _AnomalyPopup({required this.anomaly, required this.onTap});

  final Anomaly anomaly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(anomaly.severity);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              anomaly.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: healthInk,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${anomaly.severity.label} • '
              '${(anomaly.confidence * 100).round()}% AI confidence',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: healthInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(healthyColor, 'Healthy'),
          item(warningColor, 'Warning'),
          item(criticalColor, 'Critical'),
        ],
      ),
    );
  }
}
