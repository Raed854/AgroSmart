import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const userLocationColor = Color(0xFF1E88E5);

/// Blue "you are here" dot for flutter_map.
Marker userLocationMarker(LatLng position) => Marker(
  point: position,
  width: 44,
  height: 44,
  child: const _UserLocationDot(),
);

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: userLocationColor.withValues(alpha: .18),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: userLocationColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
    ),
  );
}

/// Round map control that shows a spinner while [isBusy].
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isBusy = false,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isBusy;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isBusy ? null : onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: isBusy
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Icon(icon, color: color ?? const Color(0xFF2E7D32)),
        ),
      ),
    ),
  );
}
