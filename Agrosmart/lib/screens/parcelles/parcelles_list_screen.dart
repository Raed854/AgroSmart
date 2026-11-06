import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/parcelle_model.dart';
import '../../services/parcelle_repository.dart';
import 'parcelle_detail_screen.dart';
import 'parcelle_form_screen.dart';
import 'parcelles_analysis_screen.dart';
import 'parcelles_map_screen.dart';

class ParcellesListScreen extends StatefulWidget {
  const ParcellesListScreen({super.key});

  @override
  State<ParcellesListScreen> createState() => _ParcellesListScreenState();
}

class _ParcellesListScreenState extends State<ParcellesListScreen> {
  final _parcelleRepository = ParcelleRepository();
  List<ParcelleModel> _parcelles = [];
  List<ParcelleModel> _filteredParcelles = [];
  bool _isLoading = true;
  bool _showArchived = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadParcelles();
    _searchController.addListener(_filterParcelles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParcelles() async {
    setState(() => _isLoading = true);
    try {
      final parcelles =
          await _parcelleRepository.getAll(includeArchived: _showArchived);
      setState(() {
        _parcelles = parcelles;
        _filteredParcelles = parcelles;
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

  void _filterParcelles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParcelles = _parcelles
          .where((p) => p.nom.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text('Parcelles', style: TextStyle(color: inkGreen)),
        iconTheme: const IconThemeData(color: inkGreen),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Analyse des parcelles',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ParcellesAnalysisScreen(
                  parcelles: _parcelles,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Carte',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ParcellesMapScreen()),
            ),
          ),
          IconButton(
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip:
                _showArchived ? 'Masquer archivées' : 'Afficher archivées',
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _loadParcelles();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ParcelleFormScreen(),
            ),
          );
          if (result == true) _loadParcelles();
        },
        backgroundColor: forestGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_filteredParcelles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.landscape_outlined,
              size: 64,
              color: mutedGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Aucune parcelle trouvée'
                  : 'Aucune parcelle',
              style: const TextStyle(
                color: mutedGreen,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Essayez une autre recherche'
                  : 'Créez votre première parcelle',
              style: TextStyle(color: mutedGreen.withValues(alpha: 0.8)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher une parcelle...',
              prefixIcon: const Icon(Icons.search, color: mutedGreen),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: mutedGreen),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderGreen),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderGreen),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: forestGreen, width: 2),
              ),
            ),
          ),
        ),
        // Liste des parcelles
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _filteredParcelles.length,
            itemBuilder: (context, index) =>
                _buildParcelleCard(_filteredParcelles[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildParcelleCard(ParcelleModel parcelle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: parcelle.archivee
              ? mutedGreen.withValues(alpha: 0.3)
              : borderGreen,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: parcelle.archivee
              ? mutedGreen.withValues(alpha: 0.2)
              : const Color(0xFFEAF6E5),
          child: Icon(
            Icons.terrain_rounded,
            color: parcelle.archivee ? mutedGreen : forestGreen,
          ),
        ),
        title: Text(
          parcelle.nom,
          style: TextStyle(
            color: inkGreen,
            fontWeight: FontWeight.w800,
            decoration: parcelle.archivee ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${parcelle.surface.toStringAsFixed(1)} ha  •  ${parcelle.typeSol}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: mutedGreen),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParcelleDetailScreen(parcelle: parcelle),
            ),
          );
          if (result == true) _loadParcelles();
        },
      ),
    );
  }
}
