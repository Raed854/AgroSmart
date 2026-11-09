// Écran inventaire – module 3.6 Gestion des stocks
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/saved_filter.dart';
import '../models/stock_product.dart';
import '../services/saved_filter_service.dart';
import '../services/stock_service.dart';
import '../utils/unit_converter.dart';
import 'stock_alerts_screen.dart';
import 'stock_assistant_screen.dart';
import 'stock_detail_screen.dart';
import 'stock_form_screen.dart';
import 'stock_history_screen.dart';
import 'stock_suggestions_screen.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  final _service = StockService.instance;
  final _filterService = SavedFilterService.instance;
  final _searchCtrl = TextEditingController();

  List<StockProduct> _all = [];
  List<StockProduct> _filtered = [];
  List<SavedFilter> _savedFilters = [];
  int _alertCount = 0;
  bool _loading = true;
  String? _error;

  ProductCategory? _filterCategory;
  bool _filterLow = false;
  bool _filterExpiring = false;
  bool _showArchived = false;

  /// Filtre enregistré actuellement actif (null = aucun).
  SavedFilter? _activePreset;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _service.getProducts(
        includeArchived: _showArchived,
      );
      final count = await _service.getAlertCount();
      final savedFilters = await _filterService.getFilters();
      if (!mounted) return;
      setState(() {
        _all = products;
        _alertCount = count;
        _savedFilters = savedFilters;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        // Archivage
        if (!_showArchived && p.archived) return false;
        if (_showArchived && !p.archived) return false;

        if (query.isNotEmpty &&
            !p.name.toLowerCase().contains(query) &&
            !p.category.label.toLowerCase().contains(query)) {
          return false;
        }
        if (_filterCategory != null && p.category != _filterCategory) {
          return false;
        }
        if (_filterLow && !p.isLow) return false;
        return true;
      }).toList();
    });
  }

  /// Applique un filtre enregistré : remplace les filtres actifs.
  void _applyPreset(SavedFilter filter) {
    setState(() {
      _activePreset = filter;
      _filterCategory = filter.category;
      _filterLow = filter.filterLow;
      _filterExpiring = filter.filterExpiring;
      _showArchived = filter.filterArchived;
      if (filter.searchText != null && filter.searchText!.isNotEmpty) {
        _searchCtrl.text = filter.searchText!;
      }
    });
    // Recharge avec le bon état archivé
    _load();
  }

  void _clearPreset() {
    setState(() {
      _activePreset = null;
      _filterCategory = null;
      _filterLow = false;
      _filterExpiring = false;
      _showArchived = false;
      _searchCtrl.clear();
    });
    _load();
  }

  bool get _hasActiveFilters =>
      _filterCategory != null ||
      _filterLow ||
      _filterExpiring ||
      _searchCtrl.text.trim().isNotEmpty;

  Future<void> _openAlerts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockAlertsScreen()),
    );
    _load();
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockHistoryScreen()),
    );
  }

  Future<void> _openSuggestions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockSuggestionsScreen()),
    );
  }

  Future<void> _openAssistant() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockAssistantScreen()),
    );
    _load();
  }

  Future<void> _addProduct() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StockFormScreen()),
    );
    if (added == true) _load();
  }

  // ── Filtres enregistrés ──────────────────────────────────────────────────

  Future<void> _saveCurrentFilter() async {
    final nameCtrl = TextEditingController();
    final error = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enregistrer ce filtre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Critères : ${_buildCurrentFilter('').criteriaLabel}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6E7F72)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              maxLength: SavedFilterService.maxNameLength,
              decoration: InputDecoration(
                labelText: 'Nom du filtre',
                hintText: 'ex. Semences à commander',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (error == null || error.trim().isEmpty) return;
    try {
      await _filterService.saveFilter(_buildCurrentFilter(error));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Filtre enregistré.')));
      }
      _load();
    } on SavedFilterException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  SavedFilter _buildCurrentFilter(String name) => SavedFilter(
    name: name,
    category: _filterCategory,
    filterLow: _filterLow,
    filterExpiring: _filterExpiring,
    filterArchived: _showArchived,
    searchText: _searchCtrl.text.trim().isEmpty
        ? null
        : _searchCtrl.text.trim(),
    createdAt: DateTime.now(),
  );

  Future<void> _renameFilter(SavedFilter filter) async {
    final ctrl = TextEditingController(text: filter.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le filtre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: SavedFilterService.maxNameLength,
          decoration: InputDecoration(
            labelText: 'Nouveau nom',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    try {
      await _filterService.renameFilter(filter.id!, newName);
      _load();
    } on SavedFilterException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteFilter(SavedFilter filter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce filtre ?'),
        content: Text(
          'Le filtre "${filter.name}" sera supprimé définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _filterService.deleteFilter(filter.id!);
      if (_activePreset?.id == filter.id) _clearPreset();
      _load();
    } on SavedFilterException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openDetail(StockProduct product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(productId: product.id!),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text(
          'Stocks et produits',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
        actions: [
          IconButton(
            tooltip: 'Assistant stock',
            icon: const Icon(Icons.forum_outlined),
            onPressed: _openAssistant,
          ),
          // Suggestions IA
          IconButton(
            tooltip: 'Suggestions de réapprovisionnement',
            icon: const Icon(Icons.auto_graph_rounded),
            onPressed: _openSuggestions,
          ),
          // Historique
          IconButton(
            tooltip: 'Historique des mouvements',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openHistory,
          ),
          // Alertes avec badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Alertes',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _openAlerts,
              ),
              if (_alertCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_alertCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        backgroundColor: forestGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
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

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(StockProduct product) async {
    await _service.toggleFavorite(product.id!);
    _load();
  }

  Widget _body() {
    final favorites = _filtered
        .where((p) => p.favorite && !p.archived)
        .toList();
    final others = _filtered
        .where((p) => !(p.favorite && !p.archived))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 96),
      children: [
        _summary(),
        const SizedBox(height: 16),
        _assistantCard(),
        const SizedBox(height: 16),
        _searchBar(),
        const SizedBox(height: 8),
        // ── Puces des filtres enregistrés ──
        if (_savedFilters.isNotEmpty) _savedFilterChips(),
        const SizedBox(height: 8),
        _filterChips(),
        // ── Bouton enregistrer filtre actif ──
        if (_hasActiveFilters) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saveCurrentFilter,
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text(
                'Enregistrer ce filtre',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: forestGreen,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),

        // ── Section favoris ──
        if (favorites.isNotEmpty) ...[
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFB300),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Épinglés',
                style: TextStyle(
                  color: inkGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB300)),
                ),
                child: Text(
                  '${favorites.length}',
                  style: const TextStyle(
                    color: Color(0xFF7A5700),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...favorites.map(_productCard),
          const SizedBox(height: 16),
        ],

        // ── En-tête inventaire ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              favorites.isNotEmpty
                  ? 'Autres produits'
                  : (_showArchived ? 'Tous les produits' : 'Inventaire actif'),
              style: const TextStyle(
                color: inkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _showArchived = !_showArchived);
                _load();
              },
              child: Text(
                _showArchived ? 'Masquer archivés' : 'Voir archivés',
                style: const TextStyle(color: mutedGreen, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_filtered.isEmpty)
          _emptyView()
        else if (others.isEmpty && favorites.isNotEmpty)
          const SizedBox.shrink()
        else if (others.isEmpty)
          _emptyView()
        else
          ...others.map(_productCard),
      ],
    );
  }

  Widget _assistantCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFFEAF6E5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFB7DDB0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.forum_outlined, color: forestGreen),
        ),
        title: const Text(
          'Assistant stock',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Posez une question sur vos stocks, alertes ou mouvements.',
        ),
        trailing: const Icon(Icons.arrow_forward_rounded, color: forestGreen),
        onTap: _openAssistant,
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: forestGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: .16),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${_all.length} produit(s) suivi(s)\n$_alertCount alerte(s) active(s)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Rechercher un produit…',
        prefixIcon: const Icon(Icons.search_rounded, color: mutedGreen),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: mutedGreen),
                onPressed: () {
                  _searchCtrl.clear();
                  _applyFilters();
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGreen),
        ),
      ),
    );
  }

  Widget _savedFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Bouton "Tout effacer" si un preset est actif
          if (_activePreset != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Effacer', style: TextStyle(fontSize: 11)),
                onPressed: _clearPreset,
                side: const BorderSide(color: Color(0xFFE53935)),
                backgroundColor: const Color(0xFFFFF0F0),
              ),
            ),
          ..._savedFilters.map((f) {
            final isActive = _activePreset?.id == f.id;
            final resultCount = SavedFilterService.countResults(f, _all);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: f.isPreset ? null : () => _showFilterMenu(f),
                child: FilterChip(
                  label: Text(
                    '${f.name} ($resultCount)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  avatar: f.isPreset
                      ? null
                      : const Icon(Icons.bookmark_rounded, size: 14),
                  selected: isActive,
                  onSelected: (_) =>
                      isActive ? _clearPreset() : _applyPreset(f),
                  selectedColor: const Color(0xFFEAF6E5),
                  checkmarkColor: forestGreen,
                  side: BorderSide(color: isActive ? forestGreen : borderGreen),
                  tooltip: f.criteriaLabel,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showFilterMenu(SavedFilter filter) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                filter.name,
                style: const TextStyle(
                  color: inkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                filter.criteriaLabel,
                style: const TextStyle(color: mutedGreen, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: inkGreen),
              title: const Text('Renommer'),
              onTap: () {
                Navigator.pop(context);
                _renameFilter(filter);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
              ),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteFilter(filter);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            'Stock faible',
            _filterLow,
            () => setState(() {
              _filterLow = !_filterLow;
              _applyFilters();
            }),
            icon: Icons.trending_down_rounded,
          ),
          const SizedBox(width: 8),
          _chip(
            'Expire bientôt',
            _filterExpiring,
            () => setState(() {
              _filterExpiring = !_filterExpiring;
              _applyFilters();
            }),
            icon: Icons.event_busy_outlined,
          ),
          const SizedBox(width: 8),
          ...ProductCategory.values.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(
                cat.label,
                _filterCategory == cat,
                () => setState(() {
                  _filterCategory = _filterCategory == cat ? null : cat;
                  _applyFilters();
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: icon != null ? Icon(icon, size: 16) : null,
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFEAF6E5),
      checkmarkColor: forestGreen,
      side: BorderSide(color: selected ? forestGreen : borderGreen),
    );
  }

  Widget _emptyView() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: mutedGreen),
            SizedBox(height: 12),
            Text('Aucun produit trouvé.', style: TextStyle(color: mutedGreen)),
          ],
        ),
      ),
    );
  }

  Widget _productCard(StockProduct product) {
    final isArchived = product.archived;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isArchived ? const Color(0xFFF5F5F5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: product.isLow && !isArchived
              ? const Color(0xFFFFCC80)
              : borderGreen,
        ),
      ),
      child: InkWell(
        onTap: () => _openDetail(product),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isArchived
                    ? const Color(0xFFEEEEEE)
                    : product.isLow
                    ? const Color(0xFFFFE9D5)
                    : const Color(0xFFEAF6E5),
                child: Icon(
                  _iconFor(product.category),
                  color: isArchived
                      ? mutedGreen
                      : product.isLow
                      ? const Color(0xFFB36B00)
                      : forestGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: TextStyle(
                              color: isArchived ? mutedGreen : inkGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isArchived)
                          const Chip(
                            label: Text(
                              'Archivé',
                              style: TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (product.isLow && !isArchived)
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Color(0xFFB36B00),
                          ),
                        // Étoile favori
                        if (!isArchived)
                          GestureDetector(
                            onTap: () => _toggleFavorite(product),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                product.favorite
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 20,
                                color: product.favorite
                                    ? const Color(0xFFFFB300)
                                    : mutedGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.category.label,
                      style: const TextStyle(color: mutedGreen, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _quantityBadge(product),
                        const SizedBox(width: 8),
                        Text(
                          'Seuil : ${UnitConverter.smartDisplay(product.minThreshold, product.unit)}',
                          style: const TextStyle(
                            color: mutedGreen,
                            fontSize: 11,
                          ),
                        ),
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

  Widget _quantityBadge(StockProduct product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: product.isLow
            ? const Color(0xFFFFE9D5)
            : const Color(0xFFEAF6E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        UnitConverter.smartDisplay(product.totalQuantity, product.unit),
        style: TextStyle(
          color: product.isLow ? const Color(0xFFB36B00) : forestGreen,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
