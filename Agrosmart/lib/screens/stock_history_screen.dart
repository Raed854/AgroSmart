// Historique global des mouvements – module 3.6
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/stock_movement.dart';
import '../models/stock_product.dart';
import '../services/stock_service.dart';
import '../utils/unit_converter.dart';

class StockHistoryScreen extends StatefulWidget {
  const StockHistoryScreen({super.key});

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  final _service = StockService.instance;

  List<StockMovement> _movements = [];
  List<StockProduct> _products = [];
  bool _loading = true;
  String? _error;

  // Filtres
  StockProduct? _filterProduct;
  MovementType? _filterType;
  DateTime? _filterFrom;
  DateTime? _filterTo;

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
      final products = await _service.getProducts(includeArchived: true);
      final movements = await _service.getMovements(
        productId: _filterProduct?.id,
        type: _filterType,
        from: _filterFrom,
        to: _filterTo,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _movements = movements;
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

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_filterFrom ?? DateTime.now().subtract(const Duration(days: 30)))
        : (_filterTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _filterFrom = picked;
      } else {
        _filterTo = picked;
      }
    });
    _load();
  }

  void _resetFilters() {
    setState(() {
      _filterProduct = null;
      _filterType = null;
      _filterFrom = null;
      _filterTo = null;
    });
    _load();
  }

  String? _productName(int productId) {
    try {
      return _products.firstWhere((p) => p.id == productId).name;
    } catch (_) {
      return null;
    }
  }

  String? _productUnit(int productId) {
    try {
      return _products.firstWhere((p) => p.id == productId).unit;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text(
          'Historique des mouvements',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
        actions: [
          if (_filterProduct != null ||
              _filterType != null ||
              _filterFrom != null ||
              _filterTo != null)
            IconButton(
              tooltip: 'Réinitialiser les filtres',
              icon: const Icon(Icons.filter_alt_off_outlined),
              onPressed: _resetFilters,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _filterBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorView()
                      : _list(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Filtre produit
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Produit',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: borderGreen),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: borderGreen),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<StockProduct?>(
                value: _filterProduct == null
                    ? null
                    : _products.firstWhere(
                        (p) => p.id == _filterProduct!.id,
                        orElse: () => _filterProduct!,
                      ),
                isExpanded: true,
                isDense: true,
                items: [
                  const DropdownMenuItem<StockProduct?>(
                    value: null,
                    child: Text('Tous les produits'),
                  ),
                  ..._products.map(
                    (p) => DropdownMenuItem<StockProduct?>(
                      value: p,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _filterProduct = v);
                  _load();
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Filtre type
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: borderGreen),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: borderGreen),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MovementType?>(
                      value: _filterType,
                      isExpanded: true,
                      isDense: true,
                      items: const [
                        DropdownMenuItem<MovementType?>(
                          value: null,
                          child: Text('Tous'),
                        ),
                        DropdownMenuItem<MovementType?>(
                          value: MovementType.entree,
                          child: Text('Entrées'),
                        ),
                        DropdownMenuItem<MovementType?>(
                          value: MovementType.sortie,
                          child: Text('Sorties'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _filterType = v);
                        _load();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Dates
              Expanded(
                child: _dateChip(
                  _filterFrom != null
                      ? 'Du ${_dateFormat.format(_filterFrom!)}'
                      : 'Date début',
                  () => _pickDate(true),
                  _filterFrom != null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _dateChip(
                  _filterTo != null
                      ? 'Au ${_dateFormat.format(_filterTo!)}'
                      : 'Date fin',
                  () => _pickDate(false),
                  _filterTo != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String label, VoidCallback onTap, bool active) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF6E5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? forestGreen : borderGreen,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? forestGreen : mutedGreen,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
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

  Widget _list() {
    if (_movements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: mutedGreen),
            SizedBox(height: 12),
            Text(
              'Aucun mouvement trouvé.',
              style: TextStyle(color: mutedGreen),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _movements.length,
        itemBuilder: (_, i) => _movementTile(_movements[i]),
      ),
    );
  }

  Widget _movementTile(StockMovement m) {
    final isEntree = m.type == MovementType.entree;
    final productName = _productName(m.productId) ?? '#${m.productId}';
    final unit = _productUnit(m.productId) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderGreen),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEntree
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFCE4EC),
          child: Icon(
            isEntree
                ? Icons.add_circle_outline_rounded
                : Icons.remove_circle_outline_rounded,
            color: isEntree
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
          ),
        ),
        title: Text(
          productName,
          style: const TextStyle(
            color: inkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${m.type.label} · ${UnitConverter.smartDisplay(m.quantity, unit)} · ${_dateFormat.format(m.date)}',
              style: const TextStyle(fontSize: 12, color: mutedGreen),
            ),
            if (m.note != null && m.note!.isNotEmpty)
              Text(
                m.note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: mutedGreen,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        isThreeLine: m.note != null && m.note!.isNotEmpty,
      ),
    );
  }
}
