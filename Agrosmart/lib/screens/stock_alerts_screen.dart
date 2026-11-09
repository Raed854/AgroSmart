// Écran alertes – module 3.6
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/stock_batch.dart';
import '../models/stock_product.dart';
import '../services/stock_service.dart';
import '../utils/unit_converter.dart';
import 'stock_detail_screen.dart';

class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key});

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  final _service = StockService.instance;

  List<StockProduct> _lowStock = [];
  List<StockBatch> _expiring = [];
  // Produits correspondant aux lots expirés/expirants
  final Map<int, StockProduct> _batchProducts = {};
  bool _loading = true;
  String? _error;

  static const int _expiryDays = 30;
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
      final low = await _service.getLowStockProducts();
      final expiring = await _service.getExpiringBatches(days: _expiryDays);

      // Charge les produits associés aux lots
      final Map<int, StockProduct> map = {};
      for (final batch in expiring) {
        if (!map.containsKey(batch.productId)) {
          final p = await _service.getProduct(batch.productId);
          if (p != null) map[batch.productId] = p;
        }
      }

      if (!mounted) return;
      setState(() {
        _lowStock = low;
        _expiring = expiring;
        _batchProducts.clear();
        _batchProducts.addAll(map);
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
          'Alertes de stock',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
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
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );

  Widget _body() {
    final totalAlerts = _lowStock.length + _expiring.length;

    if (totalAlerts == 0) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 56, color: forestGreen),
            SizedBox(height: 16),
            Text(
              'Aucune alerte active.',
              style: TextStyle(
                color: inkGreen,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tous vos stocks sont dans les normes.',
              style: TextStyle(color: mutedGreen),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Résumé
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5DD),
              borderRadius: BorderRadius.circular(18),
              border: const Border.fromBorderSide(
                BorderSide(color: Color(0xFFFFCC80)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB36B00),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '$totalAlerts alerte(s) active(s)',
                  style: const TextStyle(
                    color: Color(0xFF7A4B00),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Stock faible ──
          if (_lowStock.isNotEmpty) ...[
            _sectionHeader(
              'Stock faible',
              Icons.trending_down_rounded,
              const Color(0xFFE65100),
            ),
            const SizedBox(height: 8),
            ..._lowStock.map(_lowStockCard),
            const SizedBox(height: 20),
          ],

          // ── Expiration ──
          if (_expiring.isNotEmpty) ...[
            _sectionHeader(
              'Expiration proche ou passée',
              Icons.event_busy_rounded,
              const Color(0xFFC62828),
            ),
            const SizedBox(height: 8),
            ..._expiring.map(_expiryCard),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _lowStockCard(StockProduct product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFFFF5DD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFFFCC80)),
      ),
      child: ListTile(
        onTap: () => _openDetail(product.id!),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFE0B2),
          child: Icon(Icons.inventory_2_outlined, color: Color(0xFFE65100)),
        ),
        title: Text(
          product.name,
          style: const TextStyle(
            color: inkGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Stock : ${UnitConverter.smartDisplay(product.totalQuantity, product.unit)}  ·  Seuil : ${UnitConverter.smartDisplay(product.minThreshold, product.unit)}',
          style: const TextStyle(color: Color(0xFF7A4B00), fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: mutedGreen,
        ),
      ),
    );
  }

  Widget _expiryCard(StockBatch batch) {
    final product = _batchProducts[batch.productId];
    final expired = batch.isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: expired
          ? const Color(0xFFFFF0F0)
          : const Color(0xFFFFF5DD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: expired
              ? const Color(0xFFE53935)
              : const Color(0xFFFFCC80),
        ),
      ),
      child: ListTile(
        onTap: product != null ? () => _openDetail(product.id!) : null,
        leading: CircleAvatar(
          backgroundColor: expired
              ? const Color(0xFFFFCDD2)
              : const Color(0xFFFFE0B2),
          child: Icon(
            Icons.event_busy_rounded,
            color: expired
                ? const Color(0xFFC62828)
                : const Color(0xFFE65100),
          ),
        ),
        title: Text(
          product?.name ?? 'Produit #${batch.productId}',
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Lot ${batch.batchNumber} · ${UnitConverter.smartDisplay(batch.quantity, product?.unit ?? '')}\n'
          '${expired ? 'Expiré le' : 'Expire le'} ${_dateFormat.format(batch.expiryDate!)}',
          style: TextStyle(
            color: expired
                ? const Color(0xFFC62828)
                : const Color(0xFF7A4B00),
            fontSize: 12,
          ),
        ),
        isThreeLine: true,
        trailing: expired
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Expiré',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : const Icon(Icons.chevron_right_rounded, color: mutedGreen),
      ),
    );
  }

  Future<void> _openDetail(int productId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(productId: productId),
      ),
    );
    _load();
  }
}
