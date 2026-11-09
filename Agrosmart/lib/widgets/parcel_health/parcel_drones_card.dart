import 'package:flutter/material.dart';

import '../../models/drone.dart';
import '../drone_visuals.dart';
import 'health_palette.dart';

/// Lists, by name, the drones responsible for the selected parcel.
class ParcelDronesCard extends StatelessWidget {
  const ParcelDronesCard({
    super.key,
    required this.drones,
    required this.hasAnyDrone,
    required this.onSelect,
    required this.onCreateDrone,
  });

  /// Drones responsible for the parcel.
  final List<Drone> drones;

  /// Whether the farm has at least one drone to choose from.
  final bool hasAnyDrone;

  final VoidCallback onSelect;
  final VoidCallback onCreateDrone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: healthCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.flight_rounded, color: healthPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Drones responsables (${drones.length})',
                  style: const TextStyle(
                    color: healthInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasAnyDrone)
                TextButton.icon(
                  onPressed: onSelect,
                  style: TextButton.styleFrom(foregroundColor: healthPrimary),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Choisir'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasAnyDrone)
            _Hint(
              text:
                  'Aucun drone enregistré. Créez un drone pour pouvoir '
                  "l'affecter à cette parcelle.",
              action: 'Créer un drone',
              onTap: onCreateDrone,
            )
          else if (drones.isEmpty)
            _Hint(
              text:
                  'Aucun drone responsable. Choisissez au moins un drone '
                  'pour cette parcelle.',
              action: 'Choisir des drones',
              onTap: onSelect,
              warning: true,
            )
          else
            for (final drone in drones) _DroneRow(drone: drone),
        ],
      ),
    );
  }
}

class _DroneRow extends StatelessWidget {
  const _DroneRow({required this.drone});

  final Drone drone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        DroneThumbnail(drone: drone, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                drone.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: healthInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${drone.type.label}  •  ${drone.brand} ${drone.model}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: healthMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        DroneStatusChip(status: drone.status),
      ],
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.text,
    required this.action,
    required this.onTap,
    this.warning = false,
  });

  final String text;
  final String action;
  final VoidCallback onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        text,
        style: TextStyle(
          color: warning ? const Color(0xFF9A6B00) : healthMuted,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(foregroundColor: healthPrimary),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(action),
      ),
    ],
  );
}

/// Bottom sheet listing every drone by name with a checkbox. Returns the
/// chosen ids, or `null` when cancelled. At least one drone is required.
Future<Set<String>?> showParcelDronePicker(
  BuildContext context, {
  required String parcelName,
  required List<Drone> drones,
  required Set<String> selected,
}) => showModalBottomSheet<Set<String>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  builder: (_) =>
      _DronePicker(parcelName: parcelName, drones: drones, initial: selected),
);

class _DronePicker extends StatefulWidget {
  const _DronePicker({
    required this.parcelName,
    required this.drones,
    required this.initial,
  });

  final String parcelName;
  final List<Drone> drones;
  final Set<String> initial;

  @override
  State<_DronePicker> createState() => _DronePickerState();
}

class _DronePickerState extends State<_DronePicker> {
  late final Set<String> _selected = Set.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Drones responsables de ${widget.parcelName}',
                style: const TextStyle(
                  color: healthInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Sélectionnez un ou plusieurs drones.',
                style: TextStyle(color: healthMuted),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final drone in widget.drones)
                    CheckboxListTile(
                      value: _selected.contains(drone.id),
                      activeColor: healthPrimary,
                      onChanged: (checked) => setState(
                        () => checked == true
                            ? _selected.add(drone.id)
                            : _selected.remove(drone.id),
                      ),
                      secondary: DroneThumbnail(drone: drone, size: 40),
                      title: Text(
                        drone.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${drone.type.label}  •  ${drone.status.label}',
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected),
                style: FilledButton.styleFrom(
                  backgroundColor: healthPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _selected.isEmpty
                      ? 'Choisissez au moins un drone'
                      : 'Enregistrer (${_selected.length})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
