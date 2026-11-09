import 'package:flutter/material.dart';

import '../main.dart';
import '../models/drone.dart';
import '../services/drone_repository.dart';
import '../widgets/drone_visuals.dart';
import 'drone_form_screen.dart';

/// Lists the farm's drone profiles and opens the form to add or edit one.
class DronesScreen extends StatefulWidget {
  const DronesScreen({super.key, this.repository});

  /// Defaults to the local sqflite database.
  final DroneRepository? repository;

  @override
  State<DronesScreen> createState() => _DronesScreenState();
}

class _DronesScreenState extends State<DronesScreen> {
  late final DroneRepository _repository =
      widget.repository ?? SqfliteDroneRepository();
  List<Drone>? _drones;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final drones = await _repository.fetchDrones();
      if (!mounted) return;
      setState(() {
        _drones = drones;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de charger les drones.');
    }
  }

  Future<void> _openForm([Drone? drone]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DroneFormScreen(
          repository: _repository,
          drone: drone,
          showDroneListButton: false,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final drones = _drones;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: const Text(
          'Drones',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: forestGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau drone'),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!))
            : drones == null
            ? const Center(child: CircularProgressIndicator())
            : drones.isEmpty
            ? _EmptyState(onAdd: () => _openForm())
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                children: [
                  _Summary(drones: drones),
                  const SizedBox(height: 16),
                  for (final drone in drones)
                    _DroneCard(drone: drone, onTap: () => _openForm(drone)),
                ],
              ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.drones});

  final List<Drone> drones;

  @override
  Widget build(BuildContext context) {
    int count(DroneStatus status) =>
        drones.where((d) => d.status == status).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: forestGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: .16),
            child: const Icon(Icons.flight_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '${drones.length} drone(s)\n'
              '${count(DroneStatus.active)} actif(s) · '
              '${count(DroneStatus.maintenance)} en maintenance · '
              '${count(DroneStatus.outOfService)} hors service',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DroneCard extends StatelessWidget {
  const _DroneCard({required this.drone, required this.onTap});

  final Drone drone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: borderGreen),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DroneThumbnail(drone: drone),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drone.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: inkGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${drone.brand} · ${drone.model}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            droneTypeIcon(drone.type),
                            size: 15,
                            color: forestGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            drone.type.label,
                            style: const TextStyle(
                              color: inkGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      DroneStatusChip(status: drone.status),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: mutedGreen),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flight_rounded, size: 56, color: freshGreen),
          const SizedBox(height: 12),
          const Text(
            'Aucun drone',
            style: TextStyle(
              color: inkGreen,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Créez le profil de votre premier drone.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(backgroundColor: forestGreen),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nouveau drone'),
          ),
        ],
      ),
    ),
  );
}
