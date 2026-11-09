import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/maintenance_record.dart';
import '../models/materiel.dart';
import '../services/maintenance_repository.dart';
import '../services/materiel_repository.dart';
import 'materiels_screen.dart';

IconData maintenanceTypeIcon(MaintenanceRecordType type) => switch (type) {
  MaintenanceRecordType.fuel => Icons.local_gas_station_outlined,
  MaintenanceRecordType.maintenance => Icons.build_outlined,
  MaintenanceRecordType.labor => Icons.engineering_outlined,
};

Color maintenanceTypeColor(MaintenanceRecordType type) => switch (type) {
  MaintenanceRecordType.fuel => const Color(0xFF1565C0),
  MaintenanceRecordType.maintenance => const Color(0xFFEF6C00),
  MaintenanceRecordType.labor => const Color(0xFF6A1B9A),
};

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

/// Unit of [MaintenanceRecord.quantity], `null` when the type has none.
String? _quantityUnit(MaintenanceRecordType type) => switch (type) {
  MaintenanceRecordType.fuel => 'L',
  MaintenanceRecordType.labor => 'h',
  MaintenanceRecordType.maintenance => null,
};

/// The "Maintenance" page: the saved equipment, each with the number of
/// fuel, maintenance and labour entries. Tapping one opens its history.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({
    super.key,
    this.materielRepository,
    this.maintenanceRepository,
  });

  /// Both default to the local sqflite database.
  final MaterielRepository? materielRepository;
  final MaintenanceRepository? maintenanceRepository;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late final MaterielRepository _materiels =
      widget.materielRepository ?? SqfliteMaterielRepository();
  late final MaintenanceRepository _records =
      widget.maintenanceRepository ?? SqfliteMaintenanceRepository();

  List<Materiel>? _items;
  Map<String, Map<MaintenanceRecordType, int>> _counts = const {};
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _materiels.fetchMateriels(),
        _records.countRecords(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Materiel>;
        _counts = results[1] as Map<String, Map<MaintenanceRecordType, int>>;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _open(Materiel materiel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MaterielMaintenanceScreen(materiel: materiel, repository: _records),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: const Text(
          'Maintenance',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            children: [
              const Text(
                'Choisissez un matériel pour suivre son carburant, sa '
                "maintenance et sa main d'œuvre.",
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Matériels enregistrés',
                      style: TextStyle(
                        color: inkGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (items != null)
                    Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: mutedGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadFailed)
                const _EmptyState(
                  icon: Icons.error_outline,
                  text: 'Impossible de charger les matériels.',
                )
              else if (items == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                const _EmptyState(
                  icon: Icons.inventory_2_outlined,
                  text:
                      'Aucun matériel enregistré.\n'
                      'Ajoutez-en depuis la page « Matériels ».',
                )
              else
                for (final materiel in items)
                  _MaterielCard(
                    materiel: materiel,
                    counts: _counts[materiel.id] ?? const {},
                    onTap: () => _open(materiel),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterielCard extends StatelessWidget {
  const _MaterielCard({
    required this.materiel,
    required this.counts,
    required this.onTap,
  });

  final Materiel materiel;
  final Map<MaintenanceRecordType, int> counts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
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
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MaterielAvatar(materiel: materiel, radius: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          materiel.name,
                          style: const TextStyle(
                            color: inkGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${materiel.brand} ${materiel.model}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: mutedGreen),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in MaintenanceRecordType.values)
                    _CountChip(type: type, count: counts[type] ?? 0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.type, required this.count});

  final MaintenanceRecordType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = maintenanceTypeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(maintenanceTypeIcon(type), size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            '${type.label} · $count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// History of one equipment: a tab per entry type, each list scrolling
/// inside its own fixed area under the totals.
class MaterielMaintenanceScreen extends StatefulWidget {
  const MaterielMaintenanceScreen({
    super.key,
    required this.materiel,
    required this.repository,
  });

  final Materiel materiel;
  final MaintenanceRepository repository;

  @override
  State<MaterielMaintenanceScreen> createState() =>
      _MaterielMaintenanceScreenState();
}

class _MaterielMaintenanceScreenState extends State<MaterielMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: MaintenanceRecordType.values.length,
    vsync: this,
  );
  List<MaintenanceRecord>? _records;
  bool _loadFailed = false;

  MaintenanceRecordType get _currentType =>
      MaintenanceRecordType.values[_tabs.index];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final records = await widget.repository.fetchRecords(widget.materiel.id);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _edit({MaintenanceRecord? record}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: pageBackground,
      builder: (_) => MaintenanceRecordForm(
        materielId: widget.materiel.id,
        type: record?.type ?? _currentType,
        record: record,
        repository: widget.repository,
      ),
    );
    if (changed == true) _load();
  }

  List<MaintenanceRecord> _ofType(MaintenanceRecordType type) =>
      (_records ?? const []).where((r) => r.type == type).toList();

  @override
  Widget build(BuildContext context) {
    final materiel = widget.materiel;
    final type = _currentType;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: Text(
          materiel.name,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: maintenanceTypeColor(type),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Ajouter ${type.label.toLowerCase()}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MaterielHeader(materiel: materiel),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final t in MaintenanceRecordType.values) ...[
                    if (t.index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _TotalCard(
                        type: t,
                        records: _ofType(t),
                        selected: t == type,
                        onTap: () => _tabs.animateTo(t.index),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: borderGreen),
                ),
                clipBehavior: Clip.antiAlias,
                child: TabBar(
                  controller: _tabs,
                  labelColor: inkGreen,
                  unselectedLabelColor: mutedGreen,
                  indicatorColor: maintenanceTypeColor(type),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                  tabs: [
                    for (final t in MaintenanceRecordType.values)
                      Tab(
                        icon: Icon(maintenanceTypeIcon(t), size: 20),
                        text: t.label,
                        iconMargin: const EdgeInsets.only(bottom: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // The fixed area: each list scrolls inside it.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: borderGreen),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildLists(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLists() {
    if (_loadFailed) {
      return const Center(
        child: _EmptyState(
          icon: Icons.error_outline,
          text: "Impossible de charger l'historique.",
        ),
      );
    }
    if (_records == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return TabBarView(
      controller: _tabs,
      children: [
        for (final t in MaintenanceRecordType.values)
          _RecordList(
            type: t,
            records: _ofType(t),
            onTap: (record) => _edit(record: record),
          ),
      ],
    );
  }
}

class _MaterielHeader extends StatelessWidget {
  const _MaterielHeader({required this.materiel});

  final Materiel materiel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: forestGreen,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        _MaterielAvatar(materiel: materiel, radius: 26, onDark: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${materiel.brand} ${materiel.model}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'N° ${materiel.serialNumber}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: .8)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 9,
                color: materielStatusColor(materiel.status),
              ),
              const SizedBox(width: 5),
              Text(
                materiel.status.label,
                style: const TextStyle(
                  color: inkGreen,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MaterielAvatar extends StatelessWidget {
  const _MaterielAvatar({
    required this.materiel,
    required this.radius,
    this.onDark = false,
  });

  final Materiel materiel;
  final double radius;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final image = materiel.imagePath;
    return CircleAvatar(
      radius: radius,
      backgroundColor: onDark
          ? Colors.white.withValues(alpha: .16)
          : const Color(0xFFEAF6E5),
      foregroundImage: image == null ? null : FileImage(File(image)),
      child: Icon(
        materielCategoryIcon(materiel.category),
        color: onDark ? Colors.white : forestGreen,
      ),
    );
  }
}

/// Total cost of one type, plus litres or hours when the type has them.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.type,
    required this.records,
    required this.selected,
    required this.onTap,
  });

  final MaintenanceRecordType type;
  final List<MaintenanceRecord> records;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = maintenanceTypeColor(type);
    final cost = records.fold<double>(0, (sum, r) => sum + r.cost);
    final unit = _quantityUnit(type);
    final quantity = records.fold<double>(
      0,
      (sum, r) => sum + (r.quantity ?? 0),
    );
    return Material(
      color: selected ? color.withValues(alpha: .1) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : borderGreen),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(maintenanceTypeIcon(type), color: color, size: 20),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMaterielPrice(cost),
                  style: const TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                unit == null
                    ? '${records.length} opération${records.length > 1 ? 's' : ''}'
                    : '${_formatNumber(quantity)} $unit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordList extends StatelessWidget {
  const _RecordList({
    required this.type,
    required this.records,
    required this.onTap,
  });

  final MaintenanceRecordType type;
  final List<MaintenanceRecord> records;
  final ValueChanged<MaintenanceRecord> onTap;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(
        child: _EmptyState(
          icon: maintenanceTypeIcon(type),
          text:
              'Aucune entrée « ${type.label} ».\n'
              'Appuyez sur « Ajouter » pour en créer une.',
        ),
      );
    }
    return ListView.separated(
      // Room at the bottom so the add button never hides the last entry.
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: borderGreen,
      ),
      itemBuilder: (_, i) =>
          _RecordTile(record: records[i], onTap: () => onTap(records[i])),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final MaintenanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = record.type;
    final color = maintenanceTypeColor(type);
    final unit = _quantityUnit(type);
    final details = [
      formatMaterielDate(record.date),
      if (record.quantity != null && unit != null)
        '${_formatNumber(record.quantity!)} $unit',
      if (record.workerName?.isNotEmpty ?? false) record.workerName!,
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: .1),
        child: Icon(maintenanceTypeIcon(type), color: color, size: 20),
      ),
      title: Text(
        record.description.isEmpty ? type.label : record.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        formatMaterielPrice(record.cost),
        style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Bottom-sheet form that adds an entry of [type], or modifies / deletes
/// [record]. Pops `true` when something was saved or deleted.
class MaintenanceRecordForm extends StatefulWidget {
  const MaintenanceRecordForm({
    super.key,
    required this.materielId,
    required this.type,
    required this.repository,
    this.record,
  });

  final String materielId;
  final MaintenanceRecordType type;
  final MaintenanceRepository repository;
  final MaintenanceRecord? record;

  @override
  State<MaintenanceRecordForm> createState() => _MaintenanceRecordFormState();
}

class _MaintenanceRecordFormState extends State<MaintenanceRecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(
    text: widget.record?.description,
  );
  late final _quantity = TextEditingController(
    text: widget.record?.quantity == null
        ? null
        : _formatNumber(widget.record!.quantity!),
  );
  late final _worker = TextEditingController(text: widget.record?.workerName);
  late final _cost = TextEditingController(
    text: widget.record == null ? null : _formatNumber(widget.record!.cost),
  );
  late DateTime _date = widget.record?.date ?? _today();
  bool _saving = false;

  MaintenanceRecordType get _type => widget.type;
  bool get _isEditing => widget.record != null;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _worker.dispose();
    _cost.dispose();
    super.dispose();
  }

  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: _today(),
      cancelText: 'Annuler',
      confirmText: 'OK',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final worker = _worker.text.trim();
    try {
      await widget.repository.saveRecord(
        MaintenanceRecord(
          id:
              widget.record?.id ??
              'record-${DateTime.now().microsecondsSinceEpoch}',
          materielId: widget.materielId,
          type: _type,
          date: _date,
          cost: _parse(_cost.text)!,
          description: _description.text.trim(),
          quantity: _quantityUnit(_type) == null
              ? null
              : _parse(_quantity.text),
          workerName: _type == MaintenanceRecordType.fuel || worker.isEmpty
              ? null
              : worker,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage("Impossible d'enregistrer. Réessayez.");
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer l'entrée ?"),
        content: const Text('Cette entrée sera supprimée définitivement.'),
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
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.deleteRecord(widget.record!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Impossible de supprimer. Réessayez.');
    }
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  String? _positiveNumber(String? value, {required bool required}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Champ obligatoire' : null;
    }
    final number = _parse(value);
    return number == null || number < 0 ? 'Nombre invalide' : null;
  }

  @override
  Widget build(BuildContext context) {
    final color = maintenanceTypeColor(_type);
    final (descLabel, descHint) = switch (_type) {
      MaintenanceRecordType.fuel => ('Type de carburant', 'ex. Gasoil'),
      MaintenanceRecordType.maintenance => (
        'Opération',
        'ex. Vidange + filtre à huile',
      ),
      MaintenanceRecordType.labor => (
        'Travail effectué',
        'ex. Labour parcelle A',
      ),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    child: Icon(maintenanceTypeIcon(_type), color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Modifier · ${_type.label}' : _type.label,
                    style: const TextStyle(
                      color: inkGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _chooseDate,
                child: InputDecorator(
                  decoration: _decoration('Date', Icons.event_outlined),
                  child: Text(formatMaterielDate(_date)),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Champ obligatoire'
                    : null,
                decoration: _decoration(
                  descLabel,
                  Icons.notes_outlined,
                ).copyWith(hintText: descHint),
              ),
              if (_type == MaintenanceRecordType.fuel) ...[
                const SizedBox(height: 14),
                _numberField(
                  _quantity,
                  'Quantité (litres)',
                  Icons.water_drop_outlined,
                  suffix: 'L',
                  required: true,
                ),
              ],
              if (_type == MaintenanceRecordType.labor) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _worker,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Champ obligatoire'
                      : null,
                  decoration: _decoration(
                    "Nom de l'ouvrier",
                    Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 14),
                _numberField(
                  _quantity,
                  "Nombre d'heures",
                  Icons.schedule_outlined,
                  suffix: 'h',
                  required: true,
                ),
              ],
              if (_type == MaintenanceRecordType.maintenance) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _worker,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(
                    'Technicien / garage (optionnel)',
                    Icons.store_outlined,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _numberField(
                _cost,
                'Coût (DT)',
                Icons.payments_outlined,
                suffix: 'DT',
                required: true,
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: forestGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(_isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(
                    _isEditing ? 'Modifier' : 'Enregistrer',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(
                      'Supprimer',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    IconData icon, {
    required String suffix,
    required bool required,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    validator: (value) => _positiveNumber(value, required: required),
    decoration: _decoration(label, icon).copyWith(suffixText: suffix),
  );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: forestGreen),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: borderGreen),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: borderGreen),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: mutedGreen, size: 40),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
