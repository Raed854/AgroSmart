import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/irrigation_record.dart';
import '../models/parcel_health.dart';
import '../services/irrigation_repository.dart';
import '../services/parcel_health_repository.dart';
import '../services/sqflite_parcel_health_repository.dart';

/// Returns the path of a picked photo, or `null` if the farmer cancelled.
typedef IrrigationPhotoPicker = Future<String?> Function(ImageSource source);

Future<String?> _pickFromDevice(ImageSource source) async =>
    (await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    ))?.path;

const _waterBlue = Color(0xFF0277BD);

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String _formatTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

String _formatDuration(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

double? _parse(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// The "Irrigation" page: the list of parcels. Selecting one opens its
/// irrigation history, where new irrigations are added.
class IrrigationScreen extends StatefulWidget {
  const IrrigationScreen({
    super.key,
    this.parcelRepository,
    this.irrigationRepository,
    this.pickPhoto = _pickFromDevice,
    this.storePhoto = storeIrrigationPhoto,
  });

  /// Both default to the local sqflite database.
  final ParcelHealthRepository? parcelRepository;
  final IrrigationRepository? irrigationRepository;
  final IrrigationPhotoPicker pickPhoto;
  final Future<String> Function(String sourcePath, String id) storePhoto;

  @override
  State<IrrigationScreen> createState() => _IrrigationScreenState();
}

class _IrrigationScreenState extends State<IrrigationScreen> {
  late final ParcelHealthRepository _parcels =
      widget.parcelRepository ?? SqfliteParcelHealthRepository();
  late final IrrigationRepository _records =
      widget.irrigationRepository ?? SqfliteIrrigationRepository();

  List<Parcel>? _items;
  Map<String, int> _counts = const {};
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _parcels.fetchParcels(),
        _records.countRecords(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Parcel>;
        _counts = results[1] as Map<String, int>;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _open(Parcel parcel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelIrrigationScreen(
          parcel: parcel,
          repository: _records,
          pickPhoto: widget.pickPhoto,
          storePhoto: widget.storePhoto,
        ),
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
          'Irrigation',
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
                'Sélectionnez une parcelle pour enregistrer et suivre ses '
                'irrigations.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Parcelles',
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
                  text: 'Impossible de charger les parcelles.',
                )
              else if (items == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                const _EmptyState(
                  icon: Icons.crop_square_outlined,
                  text:
                      'Aucune parcelle. Créez-en une depuis la carte '
                      'Parcel Health Map.',
                )
              else
                ...items.map(
                  (parcel) => _ParcelCard(
                    parcel: parcel,
                    count: _counts[parcel.id] ?? 0,
                    onTap: () => _open(parcel),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({
    required this.parcel,
    required this.count,
    required this.onTap,
  });

  final Parcel parcel;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: borderGreen),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE1F2FB),
        child: Icon(Icons.water_drop_outlined, color: _waterBlue),
      ),
      title: Text(
        parcel.name,
        style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${parcel.cropType} · ${_formatNumber(parcel.surfaceHectares)} ha\n'
        '$count irrigation${count > 1 ? 's' : ''}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

/// Irrigation history of one parcel, with the button to add one.
class ParcelIrrigationScreen extends StatefulWidget {
  const ParcelIrrigationScreen({
    super.key,
    required this.parcel,
    required this.repository,
    this.pickPhoto = _pickFromDevice,
    this.storePhoto = storeIrrigationPhoto,
  });

  final Parcel parcel;
  final IrrigationRepository repository;
  final IrrigationPhotoPicker pickPhoto;
  final Future<String> Function(String sourcePath, String id) storePhoto;

  @override
  State<ParcelIrrigationScreen> createState() => _ParcelIrrigationScreenState();
}

class _ParcelIrrigationScreenState extends State<ParcelIrrigationScreen> {
  List<IrrigationRecord>? _records;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await widget.repository.fetchRecords(widget.parcel.id);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _edit({IrrigationRecord? record}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: pageBackground,
      builder: (_) => IrrigationForm(
        parcel: widget.parcel,
        record: record,
        repository: widget.repository,
        pickPhoto: widget.pickPhoto,
        storePhoto: widget.storePhoto,
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final records = _records;
    final totalCost = (records ?? const <IrrigationRecord>[]).fold<double>(
      0,
      (sum, r) => sum + r.cost,
    );
    final totalMinutes = (records ?? const <IrrigationRecord>[]).fold<int>(
      0,
      (sum, r) => sum + r.durationMinutes,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: Text(
          parcel.name,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: forestGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Ajouter une irrigation',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: forestGreen,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${parcel.cropType} · '
                      '${_formatNumber(parcel.surfaceHectares)} ha',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Stat(
                          label: 'Irrigations',
                          value: '${records?.length ?? 0}',
                        ),
                        _Stat(
                          label: 'Durée totale',
                          value: _formatDuration(totalMinutes),
                        ),
                        _Stat(
                          label: 'Coût total',
                          value: '${_formatNumber(totalCost)} DT',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Historique des irrigations',
                style: TextStyle(
                  color: inkGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadFailed)
                const _EmptyState(
                  icon: Icons.error_outline,
                  text: 'Impossible de charger les irrigations.',
                )
              else if (records == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (records.isEmpty)
                const _EmptyState(
                  icon: Icons.water_drop_outlined,
                  text: 'Aucune irrigation enregistrée pour cette parcelle.',
                )
              else
                ...records.map(
                  (record) => _IrrigationTile(
                    record: record,
                    onTap: () => _edit(record: record),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

class _IrrigationTile extends StatelessWidget {
  const _IrrigationTile({required this.record, required this.onTap});

  final IrrigationRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = record.photoPath;
    final humidity = [
      if (record.humidityBefore != null)
        '${_formatNumber(record.humidityBefore!)}%',
      if (record.humidityAfter != null)
        '${_formatNumber(record.humidityAfter!)}%',
    ].join(' → ');
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
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: photo != null && File(photo).existsSync()
                      ? Image.file(File(photo), fit: BoxFit.cover)
                      : const ColoredBox(
                          color: Color(0xFFE1F2FB),
                          child: Icon(
                            Icons.water_drop_outlined,
                            color: _waterBlue,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDate(record.date)} · '
                      '${_formatTime(record.startMinutes)}',
                      style: const TextStyle(
                        color: inkGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.method.label} · ${record.waterSource.label} · '
                      '${_formatDuration(record.durationMinutes)}',
                    ),
                    if (humidity.isNotEmpty || record.electricityKwh != null)
                      Text(
                        [
                          if (humidity.isNotEmpty) 'Humidité $humidity',
                          if (record.electricityKwh != null)
                            '${_formatNumber(record.electricityKwh!)} kWh',
                        ].join(' · '),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatNumber(record.cost)} DT',
                style: const TextStyle(
                  color: forestGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Form to add or modify an irrigation of the selected parcel.
class IrrigationForm extends StatefulWidget {
  const IrrigationForm({
    super.key,
    required this.parcel,
    required this.repository,
    this.record,
    this.pickPhoto = _pickFromDevice,
    this.storePhoto = storeIrrigationPhoto,
  });

  final Parcel parcel;
  final IrrigationRepository repository;
  final IrrigationRecord? record;
  final IrrigationPhotoPicker pickPhoto;
  final Future<String> Function(String sourcePath, String id) storePhoto;

  @override
  State<IrrigationForm> createState() => _IrrigationFormState();
}

class _IrrigationFormState extends State<IrrigationForm> {
  final _formKey = GlobalKey<FormState>();
  late final IrrigationRecord? _initial = widget.record;

  late DateTime _date = _initial?.date ?? _today();
  late TimeOfDay _start = _initial == null
      ? TimeOfDay.now()
      : TimeOfDay(
          hour: _initial.startMinutes ~/ 60,
          minute: _initial.startMinutes % 60,
        );
  late WaterSource? _source = _initial?.waterSource;
  late IrrigationMethod? _method = _initial?.method;

  late final _durationHours = TextEditingController(
    text: _initial == null ? null : '${_initial.durationMinutes ~/ 60}',
  );
  late final _durationMinutes = TextEditingController(
    text: _initial == null ? null : '${_initial.durationMinutes % 60}',
  );
  late final _humidityBefore = _numberController(_initial?.humidityBefore);
  late final _humidityAfter = _numberController(_initial?.humidityAfter);
  late final _electricity = _numberController(_initial?.electricityKwh);
  late final _cost = _numberController(_initial?.cost);

  /// Photo path: the saved one, or a freshly picked (not yet stored) one.
  late String? _photoPath = _initial?.photoPath;
  bool _saving = false;

  bool get _isEditing => _initial != null;

  static TextEditingController _numberController(double? value) =>
      TextEditingController(text: value == null ? null : _formatNumber(value));

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _durationHours.dispose();
    _durationMinutes.dispose();
    _humidityBefore.dispose();
    _humidityAfter.dispose();
    _electricity.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: _today().add(const Duration(days: 365)),
      cancelText: 'Annuler',
      confirmText: 'OK',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _chooseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start,
      cancelText: 'Annuler',
      confirmText: 'OK',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _start = picked);
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Retirer la photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final path = await widget.pickPhoto(source);
      if (path != null && mounted) setState(() => _photoPath = path);
    } catch (_) {
      if (mounted) _showMessage("Impossible d'accéder à la photo.");
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final duration =
        (int.tryParse(_durationHours.text.trim()) ?? 0) * 60 +
        (int.tryParse(_durationMinutes.text.trim()) ?? 0);
    if (duration <= 0) {
      _showMessage("Indiquez la durée d'irrigation.");
      return;
    }
    setState(() => _saving = true);
    final id =
        _initial?.id ?? 'irrigation-${DateTime.now().microsecondsSinceEpoch}';
    try {
      var photo = _photoPath;
      if (photo != null && photo != _initial?.photoPath) {
        photo = await widget.storePhoto(photo, id);
      }
      await widget.repository.saveRecord(
        IrrigationRecord(
          id: id,
          parcelId: widget.parcel.id,
          date: _date,
          startMinutes: _start.hour * 60 + _start.minute,
          waterSource: _source!,
          durationMinutes: duration,
          method: _method!,
          humidityBefore: _parse(_humidityBefore.text),
          humidityAfter: _parse(_humidityAfter.text),
          electricityKwh: _parse(_electricity.text),
          cost: _parse(_cost.text)!,
          photoPath: photo,
        ),
      );
      if (_initial?.photoPath != null && _initial!.photoPath != photo) {
        await deleteIrrigationPhoto(_initial.photoPath);
      }
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
        title: const Text("Supprimer l'irrigation ?"),
        content: const Text('Cette irrigation sera supprimée définitivement.'),
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
      await widget.repository.deleteRecord(_initial!);
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

  String? _number(String? value, {required bool required, double? max}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Champ obligatoire' : null;
    }
    final number = _parse(value);
    if (number == null || number < 0) return 'Nombre invalide';
    if (max != null && number > max) return 'Maximum $max';
    return null;
  }

  String? _integer(String? value, {int? max}) {
    if (value == null || value.trim().isEmpty) return null;
    final number = int.tryParse(value.trim());
    if (number == null || number < 0) return 'Invalide';
    if (max != null && number > max) return 'Max $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photoPath;
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
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE1F2FB),
                    child: Icon(Icons.water_drop_outlined, color: _waterBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing
                              ? "Modifier l'irrigation"
                              : 'Nouvelle irrigation',
                          style: const TextStyle(
                            color: inkGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('Parcelle : ${widget.parcel.name}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _chooseDate,
                      child: InputDecorator(
                        decoration: _decoration(
                          "Date d'irrigation",
                          Icons.event_outlined,
                        ),
                        child: Text(_formatDate(_date)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _chooseTime,
                      child: InputDecorator(
                        decoration: _decoration(
                          'Heure de début',
                          Icons.schedule_outlined,
                        ),
                        child: Text(
                          _formatTime(_start.hour * 60 + _start.minute),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<WaterSource>(
                initialValue: _source,
                isExpanded: true,
                decoration: _decoration("Source d'eau", Icons.waves_outlined),
                items: [
                  for (final source in WaterSource.values)
                    DropdownMenuItem(value: source, child: Text(source.label)),
                ],
                validator: (value) =>
                    value == null ? 'Champ obligatoire' : null,
                onChanged: (value) => setState(() => _source = value),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationHours,
                      keyboardType: TextInputType.number,
                      validator: (value) => _integer(value),
                      decoration: _decoration(
                        "Durée d'irrigation",
                        Icons.timer_outlined,
                      ).copyWith(suffixText: 'h'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _durationMinutes,
                      keyboardType: TextInputType.number,
                      validator: (value) => _integer(value, max: 59),
                      decoration: _plainDecoration('Minutes')
                          .copyWith(suffixText: 'min'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<IrrigationMethod>(
                initialValue: _method,
                isExpanded: true,
                decoration: _decoration(
                  "Méthode d'irrigation",
                  Icons.shower_outlined,
                ),
                items: [
                  for (final method in IrrigationMethod.values)
                    DropdownMenuItem(value: method, child: Text(method.label)),
                ],
                validator: (value) =>
                    value == null ? 'Champ obligatoire' : null,
                onChanged: (value) => setState(() => _method = value),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _numberField(
                      _humidityBefore,
                      'Humidité avant',
                      Icons.opacity_outlined,
                      suffix: '%',
                      max: 100,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberField(
                      _humidityAfter,
                      'Humidité après',
                      Icons.opacity,
                      suffix: '%',
                      max: 100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _numberField(
                _electricity,
                'Consommation électrique',
                Icons.bolt_outlined,
                suffix: 'kWh',
              ),
              const SizedBox(height: 14),
              _numberField(
                _cost,
                "Coût de l'irrigation",
                Icons.payments_outlined,
                suffix: 'DT',
                required: true,
              ),
              const SizedBox(height: 14),
              const Text(
                "Photo de l'intervention",
                style: TextStyle(color: inkGreen, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _saving ? null : _choosePhoto,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderGreen),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photo != null && File(photo).existsSync()
                      ? Image.file(File(photo), fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: forestGreen,
                              size: 34,
                            ),
                            SizedBox(height: 8),
                            Text('Ajouter une photo (optionnel)'),
                          ],
                        ),
                ),
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
    bool required = false,
    double? max,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    validator: (value) => _number(value, required: required, max: max),
    decoration: _decoration(label, icon).copyWith(suffixText: suffix),
  );

  InputDecoration _decoration(String label, IconData icon) =>
      _plainDecoration(label)
          .copyWith(prefixIcon: Icon(icon, color: forestGreen));

  InputDecoration _plainDecoration(String label) => InputDecoration(
    labelText: label,
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
