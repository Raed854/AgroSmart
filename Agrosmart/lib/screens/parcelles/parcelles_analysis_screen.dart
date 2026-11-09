import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/parcelle_model.dart';
import '../../services/parcelle_ai_service.dart';

class ParcellesAnalysisScreen extends StatelessWidget {
  final List<ParcelleModel> parcelles;

  const ParcellesAnalysisScreen({super.key, required this.parcelles});

  @override
  Widget build(BuildContext context) {
    final aiService = ParcelleAIService();
    final comparison = aiService.compareParcelles(parcelles);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text(
          'Analyse des parcelles',
          style: TextStyle(color: inkGreen),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
      body: parcelles.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildSummaryCard(comparison),
                const SizedBox(height: 16),
                _buildSoilTypeDistribution(comparison),
                const SizedBox(height: 16),
                _buildDisclaimerCard(),
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
            Icons.analytics_outlined,
            size: 64,
            color: mutedGreen.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune parcelle à analyser',
            style: TextStyle(
              color: mutedGreen,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFDE7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFFE082)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Color(0xFFF57C00),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Vue d\'ensemble de vos parcelles',
                style: TextStyle(
                  color: Color(0xFFE65100),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> comparison) {
    final totalArea = comparison['totalArea'] as double;
    final averageArea = comparison['averageArea'] as double;
    final largest = comparison['largest'] as ParcelleModel?;
    final smallest = comparison['smallest'] as ParcelleModel?;
    final totalCount = comparison['totalCount'] as int;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borderGreen),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Résumé général',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: inkGreen,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              Icons.grid_on,
              'Nombre de parcelles',
              '$totalCount parcelle${totalCount > 1 ? 's' : ''}',
            ),
            const Divider(height: 24),
            _buildStatRow(
              Icons.straighten_outlined,
              'Surface totale',
              '${totalArea.toStringAsFixed(1)} ha',
            ),
            const Divider(height: 24),
            _buildStatRow(
              Icons.show_chart,
              'Surface moyenne',
              '${averageArea.toStringAsFixed(1)} ha',
            ),
            if (largest != null) ...[
              const Divider(height: 24),
              _buildStatRow(
                Icons.arrow_upward,
                'Plus grande parcelle',
                '${largest.nom} (${largest.surface.toStringAsFixed(1)} ha)',
              ),
            ],
            if (smallest != null) ...[
              const Divider(height: 24),
              _buildStatRow(
                Icons.arrow_downward,
                'Plus petite parcelle',
                '${smallest.nom} (${smallest.surface.toStringAsFixed(1)} ha)',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: forestGreen, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: mutedGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: inkGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoilTypeDistribution(Map<String, dynamic> comparison) {
    final countBySoilType = comparison['countBySoilType'] as Map<String, int>;

    if (countBySoilType.isEmpty) {
      return const SizedBox.shrink();
    }

    // Trier par nombre de parcelles (décroissant)
    final sortedEntries = countBySoilType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borderGreen),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition par type de sol',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: inkGreen,
              ),
            ),
            const SizedBox(height: 16),
            ...sortedEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSoilTypeBar(
                  entry.key,
                  entry.value,
                  countBySoilType.values.reduce((a, b) => a > b ? a : b),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilTypeBar(String soilType, int count, int maxCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              soilType,
              style: const TextStyle(
                color: inkGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$count parcelle${count > 1 ? 's' : ''}',
              style: TextStyle(
                color: mutedGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: count / maxCount,
            backgroundColor: borderGreen,
            color: forestGreen,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFFDE7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFFE082)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Color(0xFFF57C00),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ces suggestions sont indicatives, basées sur des règles simples.',
                style: TextStyle(
                  color: Color(0xFF6D4C41),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
