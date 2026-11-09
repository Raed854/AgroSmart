import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/parcel_health.dart';
import '../services/location_service.dart';
import '../utils/geo_utils.dart';
import '../widgets/parcel_health/health_palette.dart';
import '../widgets/map_aware_scroll_view.dart';
import '../widgets/parcel_health/user_location_marker.dart';

/// Where a new parcel's map opens when no parcel exists yet (Cap Bon).
const defaultMapCenter = LatLng(36.6820, 10.5940);

/// Creates or edits a parcel from its 4 corner points.
///
/// Each corner can be set by tapping the map, typing its coordinates, or
/// recording the phone's GPS position while standing on it.
class ParcelEditorScreen extends StatefulWidget {
  const ParcelEditorScreen({
    super.key,
    required this.onSave,
    this.onDelete,
    this.parcel,
    this.initialCenter = defaultMapCenter,
    this.locationService = const LocationService(),
  });

  /// `null` to create a new parcel.
  final Parcel? parcel;
  final Future<void> Function(Parcel parcel) onSave;
  final Future<void> Function(Parcel parcel)? onDelete;
  final LatLng initialCenter;
  final LocationService locationService;

  @override
  State<ParcelEditorScreen> createState() => _ParcelEditorScreenState();
}

class _ParcelEditorScreenState extends State<ParcelEditorScreen> {
  static const _cornerCount = 4;
  static const _minAreaHectares = 0.01;

  final _mapController = MapController();
  final _nameController = TextEditingController();
  final _cropController = TextEditingController();
  final _latControllers = List.generate(
    _cornerCount,
    (_) => TextEditingController(),
  );
  final _lngControllers = List.generate(
    _cornerCount,
    (_) => TextEditingController(),
  );
  final List<LatLng?> _corners = List.filled(_cornerCount, null);

  int _activeCorner = 0;
  int? _locatingCorner;
  bool _locatingMap = false;
  bool _saving = false;
  final _mapActive = ValueNotifier(false);
  int _activePointers = 0;
  LatLng? _myPosition;

  bool get _isEditing => widget.parcel != null;

  List<LatLng> get _validCorners => _corners.whereType<LatLng>().toList();

  List<LatLng> get _orderedCorners => orderPolygon(_validCorners);

  double get _areaHectares => polygonAreaHectares(_orderedCorners);

  bool get _canSave =>
      !_saving &&
      _nameController.text.trim().isNotEmpty &&
      _validCorners.length == _cornerCount &&
      _areaHectares >= _minAreaHectares;

  @override
  void initState() {
    super.initState();
    final parcel = widget.parcel;
    _nameController.text = parcel?.name ?? '';
    _cropController.text = parcel?.cropType ?? 'Tomatoes';
    if (parcel != null) {
      for (var i = 0; i < _cornerCount && i < parcel.boundary.length; i++) {
        _setCorner(i, parcel.boundary[i]);
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _mapActive.dispose();
    _nameController.dispose();
    _cropController.dispose();
    for (final controller in [..._latControllers, ..._lngControllers]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setCorner(int index, LatLng? point) {
    _corners[index] = point;
    _latControllers[index].text = point?.latitude.toStringAsFixed(6) ?? '';
    _lngControllers[index].text = point?.longitude.toStringAsFixed(6) ?? '';
  }

  /// Sets the active corner, then moves on to the next empty one.
  ///
  /// When this places the last missing corner, the map zooms to show the
  /// whole closed path.
  void _placeActiveCorner(LatLng point) {
    final wasComplete = _validCorners.length == _cornerCount;
    setState(() {
      _setCorner(_activeCorner, point);
      final nextEmpty = _corners.indexWhere((corner) => corner == null);
      if (nextEmpty != -1) _activeCorner = nextEmpty;
    });
    if (!wasComplete && _validCorners.length == _cornerCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitCorners();
      });
    }
  }

  void _clearAllCorners() => setState(() {
    for (var i = 0; i < _cornerCount; i++) {
      _setCorner(i, null);
    }
    _activeCorner = 0;
  });

  /// The 4 sides of the closed path with their midpoint and length.
  List<({LatLng midpoint, double meters})> get _sides {
    final points = _orderedCorners;
    const distance = Distance();
    return [
      for (var i = 0; i < points.length; i++)
        (
          midpoint: LatLng(
            (points[i].latitude + points[(i + 1) % points.length].latitude) / 2,
            (points[i].longitude + points[(i + 1) % points.length].longitude) /
                2,
          ),
          meters: distance(points[i], points[(i + 1) % points.length]),
        ),
    ];
  }

  void _onCoordinateTyped(int index) {
    final lat = double.tryParse(_latControllers[index].text.trim());
    final lng = double.tryParse(_lngControllers[index].text.trim());
    final isValid =
        lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;
    setState(() => _corners[index] = isValid ? LatLng(lat, lng) : null);
  }

  Future<LatLng?> _readGps() async {
    try {
      final position = await widget.locationService.currentPosition();
      if (mounted) setState(() => _myPosition = position);
      return position;
    } catch (e) {
      if (mounted) {
        _showMessage(
          e is LocationException ? e.message : 'Unable to get your position.',
        );
      }
      return null;
    }
  }

  Future<void> _recordCornerFromGps(int index) async {
    setState(() => _locatingCorner = index);
    final position = await _readGps();
    if (!mounted) return;
    setState(() => _locatingCorner = null);
    if (position == null) return;
    _activeCorner = index;
    _placeActiveCorner(position);
    _mapController.move(position, 18);
  }

  Future<void> _showMyPosition() async {
    setState(() => _locatingMap = true);
    final position = await _readGps();
    if (!mounted) return;
    setState(() => _locatingMap = false);
    if (position != null) _mapController.move(position, 18);
  }

  void _fitCorners() {
    final points = _validCorners;
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.single, 18);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  Parcel _buildParcel() => Parcel(
    id: widget.parcel?.id ?? 'parcel-${DateTime.now().millisecondsSinceEpoch}',
    name: _nameController.text.trim(),
    cropType: _cropController.text.trim().isEmpty
        ? 'Unknown crop'
        : _cropController.text.trim(),
    surfaceHectares: double.parse(_areaHectares.toStringAsFixed(2)),
    boundary: _orderedCorners,
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_buildParcel());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('Could not save the parcel. Please try again.');
      }
    }
  }

  Future<void> _delete() async {
    final parcel = widget.parcel!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete parcel?'),
        content: Text(
          '"${parcel.name}" and all its drone missions will be removed '
          'from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: criticalColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    await widget.onDelete!(parcel);
    if (mounted) Navigator.pop(context);
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  void _updatePointers(int delta) {
    _activePointers = (_activePointers + delta).clamp(0, 10);
    final isActive = _activePointers > 0;
    _mapActive.value = isActive;
  }

  @override
  Widget build(BuildContext context) {
    final corners = _validCorners;
    final area = _areaHectares;
    final isComplete = corners.length == _cornerCount;

    return Scaffold(
      backgroundColor: healthBackground,
      appBar: AppBar(
        backgroundColor: healthBackground,
        foregroundColor: healthInk,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit parcel' : 'New parcel',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isEditing && widget.onDelete != null)
            IconButton(
              tooltip: 'Delete parcel',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline, color: criticalColor),
            ),
        ],
      ),
      body: MapAwareScrollView(
        locked: _mapActive,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: healthPrimary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Set the 4 corners of your parcel: tap the map, type the '
                    'coordinates, or stand on a corner and press GPS.',
                    style: TextStyle(color: healthInk, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 320,
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
                      initialCenter: widget.initialCenter,
                      initialZoom: 17,
                      initialCameraFit: widget.parcel == null
                          ? null
                          : CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(
                                widget.parcel!.boundary,
                              ),
                              padding: const EdgeInsets.all(48),
                            ),
                      minZoom: 5,
                      maxZoom: 20,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (_, point) => _placeActiveCorner(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.my_application',
                        maxNativeZoom: 19,
                      ),
                      if (isComplete)
                        // All 4 corners set: draw the closed path.
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _orderedCorners,
                              color: healthSecondary.withValues(alpha: .35),
                              borderColor: healthPrimary,
                              borderStrokeWidth: 3,
                            ),
                          ],
                        )
                      else if (corners.length >= 2)
                        // Still selecting: dashed path in click order.
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: corners,
                              color: healthPrimary,
                              strokeWidth: 3,
                              pattern: StrokePattern.dashed(
                                segments: const [10, 6],
                              ),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_myPosition != null)
                            userLocationMarker(_myPosition!),
                          if (isComplete)
                            for (final side in _sides)
                              Marker(
                                point: side.midpoint,
                                width: 72,
                                height: 22,
                                child: _SideLengthLabel(meters: side.meters),
                              ),
                          for (var i = 0; i < _cornerCount; i++)
                            if (_corners[i] != null)
                              Marker(
                                point: _corners[i]!,
                                width: 32,
                                height: 32,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _activeCorner = i),
                                  child: _CornerBadge(
                                    number: i + 1,
                                    isActive: i == _activeCorner,
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
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: healthPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isComplete
                            ? 'Path closed · tap to move corner '
                                  '${_activeCorner + 1}'
                            : 'Tap to place corner ${_activeCorner + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      children: [
                        MapControlButton(
                          icon: Icons.my_location_rounded,
                          tooltip: 'Show my position',
                          color: userLocationColor,
                          isBusy: _locatingMap,
                          onTap: _showMyPosition,
                        ),
                        const SizedBox(height: 8),
                        MapControlButton(
                          icon: Icons.fit_screen_rounded,
                          tooltip: 'Zoom to corners',
                          onTap: _fitCorners,
                        ),
                        if (corners.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          MapControlButton(
                            icon: Icons.restart_alt_rounded,
                            tooltip: 'Clear all corners',
                            onTap: _clearAllCorners,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Corner points',
                  style: TextStyle(
                    color: healthInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${corners.length}/$_cornerCount set',
                style: const TextStyle(
                  color: healthPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _cornerCount; i++)
            _CornerTile(
              number: i + 1,
              isActive: i == _activeCorner,
              isSet: _corners[i] != null,
              isLocating: _locatingCorner == i,
              latController: _latControllers[i],
              lngController: _lngControllers[i],
              onSelect: () => setState(() => _activeCorner = i),
              onChanged: () => _onCoordinateTyped(i),
              onGps: () => _recordCornerFromGps(i),
              onClear: () => setState(() {
                _setCorner(i, null);
                _activeCorner = i;
              }),
            ),
          const SizedBox(height: 6),
          _AreaBanner(
            cornersSet: corners.length,
            areaHectares: area,
            tooSmall: corners.length == _cornerCount && area < _minAreaHectares,
          ),
          const SizedBox(height: 18),
          _LabeledField(
            controller: _nameController,
            label: 'Parcel name',
            hint: 'e.g. Tomato Field C',
            icon: Icons.label_outline_rounded,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            controller: _cropController,
            label: 'Crop type',
            hint: 'e.g. Tomatoes',
            icon: Icons.eco_outlined,
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: healthPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isEditing ? 'Save changes' : 'Create parcel',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.number, required this.isActive});

  final int number;
  final bool isActive;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isActive ? warningColor : healthPrimary,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
    ),
    alignment: Alignment.center,
    child: Text(
      '$number',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    ),
  );
}

class _SideLengthLabel extends StatelessWidget {
  const _SideLengthLabel({required this.meters});

  final double meters;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Text(
        meters >= 1000
            ? '${(meters / 1000).toStringAsFixed(2)} km'
            : '${meters.round()} m',
        style: const TextStyle(
          color: healthInk,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _CornerTile extends StatelessWidget {
  const _CornerTile({
    required this.number,
    required this.isActive,
    required this.isSet,
    required this.isLocating,
    required this.latController,
    required this.lngController,
    required this.onSelect,
    required this.onChanged,
    required this.onGps,
    required this.onClear,
  });

  final int number;
  final bool isActive;
  final bool isSet;
  final bool isLocating;
  final TextEditingController latController;
  final TextEditingController lngController;
  final VoidCallback onSelect;
  final VoidCallback onChanged;
  final VoidCallback onGps;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: healthBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: healthBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: healthBorder),
      ),
    );
    const keyboard = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? warningColor : healthBorder,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isSet ? healthPrimary : healthBorder,
              child: Text(
                '$number',
                style: TextStyle(
                  color: isSet ? Colors.white : healthMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: latController,
                keyboardType: keyboard,
                decoration: decoration('Latitude'),
                style: const TextStyle(fontSize: 13),
                onTap: onSelect,
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: lngController,
                keyboardType: keyboard,
                decoration: decoration('Longitude'),
                style: const TextStyle(fontSize: 13),
                onTap: onSelect,
                onChanged: (_) => onChanged(),
              ),
            ),
            IconButton(
              tooltip: 'Use my GPS position',
              visualDensity: VisualDensity.compact,
              onPressed: isLocating ? null : onGps,
              icon: isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(
                      Icons.gps_fixed_rounded,
                      color: userLocationColor,
                    ),
            ),
            if (isSet)
              IconButton(
                tooltip: 'Clear corner',
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, color: healthMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _AreaBanner extends StatelessWidget {
  const _AreaBanner({
    required this.cornersSet,
    required this.areaHectares,
    required this.tooSmall,
  });

  final int cornersSet;
  final double areaHectares;
  final bool tooSmall;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (tooSmall) {
      text = 'The parcel is too small. Check that the corners are correct.';
      color = criticalColor;
    } else if (cornersSet < 3) {
      text = 'Set at least 3 corners to see the parcel shape.';
      color = healthMuted;
    } else {
      text = 'Calculated surface: ${areaHectares.toStringAsFixed(2)} ha';
      color = healthPrimary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textCapitalization: TextCapitalization.sentences,
    onChanged: (_) => onChanged?.call(),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: healthPrimary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: healthBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: healthBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: healthPrimary, width: 1.5),
      ),
    ),
  );
}
