// Écran suggestions de réapprovisionnement – module 3.6
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/stock_movement.dart';
import '../services/reorder_suggestion_service.dart';
import '../services/stock_service.dart';
import '../utils/unit_converter.dart';

class StockSuggestionsScreen extends StatefulWidget {
  const StockSuggestionsScreen({super.key});

  @override
  State<StockSuggestionsScreen> createState() =>
      _StockSuggestionsScreenState();
}

class _StockSuggestionsScreenState extends State<StockSuggestionsScreen> {
  final _service = StockService.instance;
  final _suggestionService = const ReorderSuggestionService();

  List<SuggestionResult> _results = [];
  bool _loading = true;
  String? _error;

  int _windowDays = 30;
  static const _windowOptions = [30, 60, 90];

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _service.getProducts();
      final results = <SuggestionResult>[];

      for (final product in products) {        final from = DateTime.now().subtract(Duration(days: _windowDays));
        final sorties = await _service.getMovements(
          productId: product.id,
          type: MovementType.sortie,
          from: from,
        );
        results.add(
          _suggestionService.compute(
            product: product,
            sortieMovements: sorties,
            windowDays: _windowDays,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text(
          'Réapprovisionnement',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _windowSelector(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorView()
                      : _body(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _windowSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text(
            'Fenêtre d\'analyse :',
            style: TextStyle(color: inkGreen, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          ..._windowOptions.map(
            (d) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$d j'),
                selected: _windowDays == d,
                selectedColor: const Color(0xFFEAF6E5),
                onSelected: (_) {
                  setState(() => _windowDays = d);
                  _load();
                },
                side: BorderSide(
                  color: _windowDays == d ? forestGreen : borderGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );

  Widget _body() {
    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_graph_rounded, size: 48, color: mutedGreen),
            SizedBox(height: 12),
            Text(
              'Aucun produit actif.',
              style: TextStyle(color: mutedGreen),
            ),
          ],
        ),
      );
    }

    // Trier : suggestions OK d'abord, historique insuffisant ensuite
    final ok = _results.whereType<SuggestionOk>().toList()
      ..sort((a, b) => a.suggestion.daysOfCoverage
          .compareTo(b.suggestion.daysOfCoverage));
    final noHistory = _results.whereType<SuggestionNoHistory>().toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: forestGreen, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ces suggestions sont indicatives. Elles sont calculées à partir de votre historique de sorties. La décision vous appartient.',
                    style: TextStyle(color: forestGreen, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (ok.isNotEmpty) ...[
            const Text(
              'Suggestions calculées',
              style: TextStyle(
                color: inkGreen,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            ...ok.map((r) => _suggestionCard(r.suggestion)),
            const SizedBox(height: 20),
          ],

          if (noHistory.isNotEmpty) ...[
            const Text(
              'Historique insuffisant',
              style: TextStyle(
                color: mutedGreen,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Au moins ${ReorderSuggestionService.minMovements} sorties sont nécessaires pour calculer une suggestion.',
              style: const TextStyle(color: mutedGreen, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...noHistory.map((r) => _noHistoryCard(r.info)),
          ],
        ],
      ),
    );
  }

  Widget _suggestionCard(ReorderSuggestion s) {
    final urgent = s.daysOfCoverage < 7;
    final warning = s.daysOfCoverage < 14;

    Color borderColor = borderGreen;
    Color bgColor = Colors.white;
    if (urgent) {
      borderColor = const Color(0xFFE53935);
      bgColor = const Color(0xFFFFF0F0);
    } else if (warning) {
      borderColor = const Color(0xFFFFCC80);
      bgColor = const Color(0xFFFFF5DD);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: urgent
                      ? const Color(0xFFFFCDD2)
                      : const Color(0xFFEAF6E5),
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: urgent ? const Color(0xFFE53935) : forestGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.product.name,
                    style: const TextStyle(
                      color: inkGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _coverageBadge(s.daysOfCoverage),
              ],
            ),
            const SizedBox(height: 14),
            _row(
              'Consommation moy.',
              '${UnitConverter.smartDisplay(s.avgDailyConsumption, s.product.unit)}/jour',
            ),
            _row(
              'Couverture restante',
              s.daysOfCoverage.isInfinite
                  ? 'Stock sans consommation'
                  : '${s.daysOfCoverage.round()} jour(s)',
            ),
            _row(
              'Rupture estimée',
              s.daysOfCoverage.isInfinite
                  ? 'N/A'
                  : _dateFormat.format(s.estimatedStockoutDate),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quantité suggérée',
                  style: TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  UnitConverter.smartDisplay(s.suggestedQuantity, s.product.unit),
                  style: const TextStyle(
                    color: forestGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pour couvrir 30 jours · Analyse sur ${s.windowDays} jours',
              style: const TextStyle(
                color: mutedGreen,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverageBadge(double days) {
    Color bg;
    Color fg;
    String label;
    if (days.isInfinite) {
      bg = const Color(0xFFE8F5E9);
      fg = forestGreen;
      label = '∞';
    } else if (days < 7) {
      bg = const Color(0xFFFFCDD2);
      fg = const Color(0xFFC62828);
      label = '${days.round()}j';
    } else if (days < 14) {
      bg = const Color(0xFFFFE0B2);
      fg = const Color(0xFFE65100);
      label = '${days.round()}j';
    } else {
      bg = const Color(0xFFE8F5E9);
      fg = forestGreen;
      label = '${days.round()}j';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: mutedGreen, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: inkGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noHistoryCard(InsufficientHistoryResult info) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: const Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderGreen),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEEEEEE),
          child: Icon(Icons.history_toggle_off_rounded, color: mutedGreen),
        ),
        title: Text(
          info.product.name,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${info.movementCount} sortie(s) enregistrée(s) — minimum 5 requises.',
          style: const TextStyle(color: mutedGreen, fontSize: 12),
        ),
      ),
    );
  }
}
