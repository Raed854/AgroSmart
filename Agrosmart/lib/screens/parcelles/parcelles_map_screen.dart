import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../main.dart';
import '../../models/parcelle_model.dart';
import '../../services/parcelle_repository.dart';
import 'parcelle_detail_screen.dart';

class ParcellesMapScreen extends StatefulWidget {
  const ParcellesMapScreen({super.key});

  @override
  State<ParcellesMapScreen> createState() => _ParcellesMapScreenState();
}

class _ParcellesMapScreenState extends State<ParcellesMapScreen> {
  final _parcelleRepository = ParcelleRepository();
  List<ParcelleModel> _parcelles = [];
  bool _isLoading = true;
  ParcelleModel? _selectedParcelle;

  @override
  void initState() {
    super.initState();
    _loadParcelles();
  }

  Future<void> _loadParcelles() async {
    setState(() => _isLoading = true);
    try {
      final parcelles = await _parcelleRepository.getAll();
      setState(() {
        _parcelles = parcelles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  LatLng _getCenter() {
    if (_parcelles.isEmpty) {
      return LatLng(48.8566, 2.3522); // Paris par défaut
    }

    double sumLat = 0;
    double sumLon = 0;
    for (final parcelle in _parcelles) {
      sumLat += parcelle.latitude;
      sumLon += parcelle.longitude;
    }

    return LatLng(
      sumLat / _parcelles.length,
      sumLon / _parcelles.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text(
          'Carte des parcelles',
          style: TextStyle(color: inkGreen),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parcelles.isEmpty
              ? _buildEmptyState()
              : Stack(
                  children: [
                    _buildMap(),
                    if (_selectedParcelle != null) _buildParcelleInfo(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 64,
            color: mutedGreen.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune parcelle à afficher',
            style: TextStyle(
              color: mutedGreen,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Créez votre première parcelle',
            style: TextStyle(color: mutedGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center = _getCenter();

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
        onTap: (tapPosition, point) => setState(() => _selectedParcelle = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.my_application',
        ),
        MarkerLayer(
          markers: _parcelles.map((parcelle) {
            return Marker(
              point: LatLng(parcelle.latitude, parcelle.longitude),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => setState(() => _selectedParcelle = parcelle),
                child: Container(
                  decoration: BoxDecoration(
                    color: parcelle.archivee
                        ? mutedGreen.withValues(alpha: 0.8)
                        : forestGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.terrain_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildParcelleInfo() {
    if (_selectedParcelle == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderGreen),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: _selectedParcelle!.archivee
                ? mutedGreen.withValues(alpha: 0.2)
                : const Color(0xFFEAF6E5),
            child: Icon(
              Icons.terrain_rounded,
              color: _selectedParcelle!.archivee ? mutedGreen : forestGreen,
            ),
          ),
          title: Text(
            _selectedParcelle!.nom,
            style: const TextStyle(
              color: inkGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${_selectedParcelle!.surface.toStringAsFixed(1)} ha  •  ${_selectedParcelle!.typeSol}',
          ),
          trailing: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ParcelleDetailScreen(parcelle: _selectedParcelle!),
                ),
              );
              if (result == true) _loadParcelles();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Voir'),
          ),
        ),
      ),
    );
  }
}
