// Fiche produit détaillée – module 3.6
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/stock_batch.dart';
import '../models/stock_movement.dart';
import '../models/stock_product.dart';
import '../services/stock_service.dart';
import '../utils/unit_converter.dart';
import 'stock_form_screen.dart';
import 'stock_movement_screen.dart';

class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({super.key, required this.productId});
  final int productId;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = StockService.instance;
  late final TabController _tabs = TabController(length: 2, vsync: this);

  StockProduct? _product;
  List<StockBatch> _batches = [];
  List<StockMovement> _movements = [];
  bool _loading = true;
  String? _error;

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final product = await _service.getProduct(widget.productId);
      if (product == null) throw Exception('Produit introuvable.');
      final batches = await _service.getBatchesForProduct(widget.productId);
      final movements =
          await _service.getMovements(productId: widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _batches = batches;
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

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StockFormScreen(product: _product),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _addMovement() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StockMovementScreen(product: _product!),
      ),
    );
    if (done == true) _load();
  }

  Future<void> _addBatch() async {
    final batchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    DateTime? expiry;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Ajouter un lot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(batchCtrl, 'Numéro de lot', 'ex. LOT-2401'),
                const SizedBox(height: 12),
                _dialogField(
                  qtyCtrl,
                  'Quantité (${_product!.unit})',
                  'ex. 25',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setS(() => expiry = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Date d'expiration (optionnelle)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon:
                          const Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      expiry != null
                          ? DateFormat('dd/MM/yyyy').format(expiry!)
                          : 'Non renseignée',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text);
                if (batchCtrl.text.trim().isEmpty ||
                    qty == null ||
                    qty <= 0) {
                  return;
                }
                await _service.addBatch(
                  StockBatch(
                    productId: _product!.id!,
                    batchNumber: batchCtrl.text.trim(),
                    quantity: qty,
                    expiryDate: expiry,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _toggleArchive() async {
    final product = _product!;
    final isArchived = product.archived;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isArchived ? 'Désarchiver ?' : 'Archiver ?'),
        content: Text(
          isArchived
              ? 'Le produit sera à nouveau visible dans l\'inventaire.'
              : 'Le produit sera masqué de l\'inventaire. L\'historique est conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isArchived ? 'Désarchiver' : 'Archiver'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (isArchived) {
      await _service.unarchiveProduct(product.id!);
    } else {
      await _service.archiveProduct(product.id!);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: Text(
          _product?.name ?? 'Fiche produit',
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
        actions: [
          if (_product != null) ...[
            // Bouton favori
            if (!_product!.archived)
              IconButton(
                tooltip: _product!.favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                icon: Icon(
                  _product!.favorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: _product!.favorite
                      ? const Color(0xFFFFB300)
                      : inkGreen,
                ),
                onPressed: () async {
                  await StockService.instance.toggleFavorite(_product!.id!);
                  _load();
                },
              ),
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: _product!.archived ? 'Désarchiver' : 'Archiver',
              icon: Icon(
                _product!.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              onPressed: _toggleArchive,
            ),
          ],
        ],
      ),
      floatingActionButton: _product != null && !_product!.archived
          ? FloatingActionButton.extended(
              onPressed: _addMovement,
              backgroundColor: forestGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.swap_vert_rounded),
              label: const Text('Mouvement'),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : _body(),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );

  Widget _body() {
    final p = _product!;
    return Column(
      children: [
        _header(p),
        TabBar(
          controller: _tabs,
          labelColor: forestGreen,
          unselectedLabelColor: mutedGreen,
          indicatorColor: forestGreen,
          tabs: const [
            Tab(text: 'Lots'),
            Tab(text: 'Historique'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _batchesTab(),
              _historyTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(StockProduct p) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: p.isLow
                    ? const Color(0xFFFFE9D5)
                    : const Color(0xFFEAF6E5),
                radius: 22,
                child: Icon(
                  _iconFor(p.category),
                  color: p.isLow ? const Color(0xFFB36B00) : forestGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.category.label,
                      style: const TextStyle(
                        color: mutedGreen,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      p.name,
                      style: const TextStyle(
                        color: inkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              if (p.archived)
                const Chip(
                  label: Text('Archivé', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statBox(
                'Stock actuel',
                UnitConverter.smartDisplay(p.totalQuantity, p.unit),
                p.isLow ? const Color(0xFFFFE9D5) : const Color(0xFFEAF6E5),
                p.isLow ? const Color(0xFFB36B00) : forestGreen,
              ),
              const SizedBox(width: 12),
              _statBox(
                'Seuil minimal',
                UnitConverter.smartDisplay(p.minThreshold, p.unit),
                const Color(0xFFF5F5F5),
                mutedGreen,
              ),
              const SizedBox(width: 12),
              _statBox(
                'Mouvements',
                '${_movements.length}',
                const Color(0xFFF0F4FF),
                const Color(0xFF3949AB),
              ),
            ],
          ),
          if (p.notes != null && p.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              p.notes!,
              style: const TextStyle(color: mutedGreen, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: fg.withValues(alpha: .7), fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchesTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lots enregistrés',
                style: TextStyle(
                  color: inkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!(_product?.archived ?? true))
                TextButton.icon(
                  onPressed: _addBatch,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter un lot'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_batches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Aucun lot enregistré.',
                  style: TextStyle(color: mutedGreen),
                ),
              ),
            )
          else
            ..._batches.map(_batchCard),
        ],
      ),
    );
  }

  Widget _batchCard(StockBatch batch) {
    final expired = batch.isExpired;
    final expiringSoon = !expired && batch.isExpiringSoon();
    Color bg = Colors.white;
    Color border = borderGreen;
    if (expired) {
      bg = const Color(0xFFFFF0F0);
      border = const Color(0xFFE53935);
    } else if (expiringSoon) {
      bg = const Color(0xFFFFF5DD);
      border = const Color(0xFFFFCC80);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: expired
              ? const Color(0xFFFFCDD2)
              : expiringSoon
                  ? const Color(0xFFFFE9D5)
                  : const Color(0xFFEAF6E5),
          child: Icon(
            Icons.inventory_rounded,
            size: 20,
            color: expired
                ? const Color(0xFFE53935)
                : expiringSoon
                    ? const Color(0xFFB36B00)
                    : forestGreen,
          ),
        ),
        title: Text(
          batch.batchNumber,
          style: const TextStyle(
            color: inkGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              UnitConverter.smartDisplay(batch.quantity, _product!.unit),
              style: const TextStyle(fontSize: 13),
            ),
            if (batch.expiryDate != null)
              Text(
                expired
                    ? 'Expiré le ${_dateFormat.format(batch.expiryDate!)}'
                    : expiringSoon
                        ? 'Expire le ${_dateFormat.format(batch.expiryDate!)} ⚠'
                        : 'Expire le ${_dateFormat.format(batch.expiryDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: expired
                      ? const Color(0xFFE53935)
                      : expiringSoon
                          ? const Color(0xFFB36B00)
                          : mutedGreen,
                ),
              ),
          ],
        ),
        isThreeLine: batch.expiryDate != null,
      ),
    );
  }

  Widget _historyTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _movements.isEmpty
          ? const Center(
              child: Text(
                'Aucun mouvement enregistré.',
                style: TextStyle(color: mutedGreen),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _movements.length,
              itemBuilder: (_, i) => _movementTile(_movements[i]),
            ),
    );
  }

  Widget _movementTile(StockMovement m) {
    final isEntree = m.type == MovementType.entree;
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
          '${m.type.label} • ${UnitConverter.smartDisplay(m.quantity, _product!.unit)}',
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
              _dateFormat.format(m.date),
              style: const TextStyle(color: mutedGreen, fontSize: 12),
            ),
            if (m.note != null && m.note!.isNotEmpty)
              Text(
                m.note!,
                style: const TextStyle(
                  color: mutedGreen,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        isThreeLine: m.note != null && m.note!.isNotEmpty,
      ),
    );
  }

  IconData _iconFor(ProductCategory cat) => switch (cat) {
        ProductCategory.semences => Icons.grass_rounded,
        ProductCategory.engrais => Icons.eco_outlined,
        ProductCategory.medicaments => Icons.medication_outlined,
        ProductCategory.traitement => Icons.science_outlined,
      };
}
