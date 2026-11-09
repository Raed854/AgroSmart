import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../main.dart';
import '../../models/parcelle_model.dart';
import '../../services/groq_ai_service.dart';
import '../../services/parcelle_ai_service.dart';
import '../../services/parcelle_repository.dart';
import 'parcelle_form_screen.dart';

class ParcelleDetailScreen extends StatefulWidget {
  final ParcelleModel parcelle;

  const ParcelleDetailScreen({super.key, required this.parcelle});

  @override
  State<ParcelleDetailScreen> createState() => _ParcelleDetailScreenState();
}

class _ParcelleDetailScreenState extends State<ParcelleDetailScreen> {
  final _parcelleRepository = ParcelleRepository();
  final _aiService = ParcelleAIService();
  late final _groqService = GroqAIService(
    apiKey: dotenv.env['GROQ_API_KEY'] ?? '',
  );
  
  List<ParcelleModel> _allParcelles = [];
  bool _isLoadingParcelles = true;
  bool _isLoadingGroqAnalysis = false;
  String? _groqAnalysis;
  bool _showGroqAnalysis = false;

  @override
  void initState() {
    super.initState();
    _loadAllParcelles();
  }

  @override
  void dispose() {
    _groqService.dispose();
    super.dispose();
  }



  Future<void> _loadAllParcelles() async {
    setState(() => _isLoadingParcelles = true);
    try {
      final parcelles = await _parcelleRepository.getAll(includeArchived: true);
      setState(() {
        _allParcelles = parcelles;
        _isLoadingParcelles = false;
      });
    } catch (e) {
      setState(() => _isLoadingParcelles = false);
    }
  }

  Future<void> _requestGroqAnalysis() async {
    print('DEBUG: Button clicked!');
    print('DEBUG: API Key from env: ${dotenv.env['GROQ_API_KEY']?.substring(0, 10)}...');
    
    setState(() {
      _isLoadingGroqAnalysis = true;
      _showGroqAnalysis = true;
      _groqAnalysis = null;
    });

    try {
      final anomalies = _aiService.detectAnomalies(widget.parcelle, _allParcelles);
      print('DEBUG: Anomalies detected: ${anomalies.length}');
      
      final analysis = await _groqService.analyzeParcelle(
        widget.parcelle,
        anomalies,
      );
      
      print('DEBUG: Analysis result: ${analysis?.substring(0, 50)}...');

      if (mounted) {
        setState(() {
          _groqAnalysis = analysis;
          _isLoadingGroqAnalysis = false;
        });
      }
    } catch (e) {
      print('DEBUG: Error occurred: $e');
      if (mounted) {
        setState(() {
          _groqAnalysis = null;
          _isLoadingGroqAnalysis = false;
        });
      }
    }
  }



  Future<void> _deleteParcelle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer la parcelle "${widget.parcelle.nom}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _parcelleRepository.delete(widget.parcelle.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de suppression: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: Text(
          widget.parcelle.nom,
          style: const TextStyle(color: inkGreen),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ParcelleFormScreen(parcelle: widget.parcelle),
                  ),
                );
                if (!context.mounted) return;
                if (result == true) {
                  Navigator.pop(context, true);
                }
              } else if (value == 'delete') {
                await _deleteParcelle();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Modifier'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoadingParcelles
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildAIAssistantCard(),
              ],
            ),
    );
  }

  Widget _buildInfoCard() {
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
              'Informations de la parcelle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: inkGreen,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.straighten_outlined,
              'Surface',
              '${widget.parcelle.surface.toStringAsFixed(1)} ha',
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.terrain,
              'Type de sol',
              widget.parcelle.typeSol,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.location_on_outlined,
              'Coordonnées GPS',
              '${widget.parcelle.latitude.toStringAsFixed(6)}, '
                  '${widget.parcelle.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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

  Widget _buildAIAssistantCard() {
    final suggestedCrops = _aiService.suggestCrops(widget.parcelle.typeSol);
    final anomalies = _aiService.detectAnomalies(widget.parcelle, _allParcelles);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFFE082)),
      ),
      color: const Color(0xFFFFFDE7),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFFF57C00), size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Assistant IA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cultures suggérées
            Text(
              'Cultures suggérées',
              style: TextStyle(
                color: Color(0xFFEF6C00),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestedCrops
                  .map(
                    (crop) => Chip(
                      label: Text(crop),
                      backgroundColor: Colors.white,
                      labelStyle: const TextStyle(
                        color: Color(0xFFEF6C00),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      side: const BorderSide(color: Color(0xFFFFCC80)),
                    ),
                  )
                  .toList(),
            ),
            
            // Points à vérifier
            if (anomalies.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFFFCC80)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, 
                       color: Color(0xFFF57C00), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Points à vérifier',
                    style: TextStyle(
                      color: Color(0xFFEF6C00),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...anomalies.map(
                (anomaly) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Color(0xFFEF6C00))),
                      Expanded(
                        child: Text(
                          anomaly,
                          style: const TextStyle(
                            color: Color(0xFF6D4C41),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Bouton Analyse détaillée (IA)
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoadingGroqAnalysis ? null : _requestGroqAnalysis,
                icon: _isLoadingGroqAnalysis
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEF6C00),
                        ),
                      )
                    : const Icon(Icons.psychology_outlined),
                label: Text(_isLoadingGroqAnalysis
                    ? 'Analyse en cours...'
                    : 'Analyse détaillée (IA)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF6C00),
                  side: const BorderSide(color: Color(0xFFFFCC80)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            // Résultat de l'analyse Groq
            if (_showGroqAnalysis) ...[
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFFFCC80)),
              const SizedBox(height: 16),
              if (_isLoadingGroqAnalysis)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      color: Color(0xFFEF6C00),
                    ),
                  ),
                )
              else if (_groqAnalysis != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Color(0xFFEF6C00),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Analyse IA détaillée',
                            style: TextStyle(
                              color: const Color(0xFFEF6C00),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _groqAnalysis!,
                        style: const TextStyle(
                          color: Color(0xFF6D4C41),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFFF57C00),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mode démo activé. Les suggestions sont basées sur des règles locales.',
                          style: TextStyle(
                            color: const Color(0xFF6D4C41),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // Disclaimer
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFFCC80)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFF57C00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ces suggestions sont indicatives, basées sur des règles simples.',
                      style: TextStyle(
                        color: Color(0xFF6D4C41),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
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
