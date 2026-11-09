import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/materiel.dart';
import '../services/materiel_repository.dart';

/// Returns the path of a picked photo, or `null` if the farmer cancelled.
typedef MaterielImagePicker = Future<String?> Function(ImageSource source);

Future<String?> _pickFromDevice(ImageSource source) async =>
    (await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    ))?.path;

String formatMaterielDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String formatMaterielPrice(double price) =>
    '${price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2)} DT';

IconData materielCategoryIcon(MaterielCategory category) => switch (category) {
  MaterielCategory.soil => Icons.agriculture_rounded,
  MaterielCategory.planting => Icons.grass_rounded,
  MaterielCategory.harvest => Icons.local_shipping_outlined,
};

Color materielStatusColor(MaterielStatus status) => switch (status) {
  MaterielStatus.available => const Color(0xFF2E7D32),
  MaterielStatus.inUse => const Color(0xFF1565C0),
  MaterielStatus.maintenance => const Color(0xFFEF6C00),
  MaterielStatus.outOfService => const Color(0xFFC62828),
};

/// The "Matériels" page: the form to add equipment, then the list of the
/// saved equipment. Tapping a name opens it to modify or delete it.
class MaterielsScreen extends StatefulWidget {
  const MaterielsScreen({
    super.key,
    this.repository,
    this.pickImage = _pickFromDevice,
    this.storeImage = storeMaterielImage,
  });

  /// Defaults to the local sqflite database.
  final MaterielRepository? repository;
  final MaterielImagePicker pickImage;
  final Future<String> Function(String sourcePath, String id) storeImage;

  @override
  State<MaterielsScreen> createState() => _MaterielsScreenState();
}

class _MaterielsScreenState extends State<MaterielsScreen> {
  late final MaterielRepository _repository =
      widget.repository ?? SqfliteMaterielRepository();
  List<Materiel>? _materiels;
  bool _loadFailed = false;

  /// Changed after each creation so the form starts empty again.
  int _formGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final materiels = await _repository.fetchMateriels();
      if (mounted) {
        setState(() {
          _materiels = materiels;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _onCreated() {
    setState(() => _formGeneration++);
    _load();
  }

  Future<void> _open(Materiel materiel) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaterielDetailScreen(
          materiel: materiel,
          repository: _repository,
          pickImage: widget.pickImage,
          storeImage: widget.storeImage,
        ),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final materiels = _materiels;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: const Text(
          'Matériels',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            const _SectionLabel('Nouveau matériel'),
            const SizedBox(height: 14),
            MaterielForm(
              key: ValueKey(_formGeneration),
              repository: _repository,
              pickImage: widget.pickImage,
              storeImage: widget.storeImage,
              onSaved: _onCreated,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Expanded(child: _SectionLabel('Matériels enregistrés')),
                if (materiels != null)
                  Text(
                    '${materiels.length}',
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
            else if (materiels == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (materiels.isEmpty)
              const _EmptyState(
                icon: Icons.inventory_2_outlined,
                text: 'Aucun matériel enregistré pour le moment',
              )
            else
              for (final materiel in materiels)
                _MaterielTile(materiel: materiel, onTap: () => _open(materiel)),
          ],
        ),
      ),
    );
  }
}

/// Shows a saved equipment, to modify or delete it.
class MaterielDetailScreen extends StatelessWidget {
  const MaterielDetailScreen({
    super.key,
    required this.materiel,
    required this.repository,
    this.pickImage = _pickFromDevice,
    this.storeImage = storeMaterielImage,
  });

  final Materiel materiel;
  final MaterielRepository repository;
  final MaterielImagePicker pickImage;
  final Future<String> Function(String sourcePath, String id) storeImage;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: pageBackground,
      elevation: 0,
      iconTheme: const IconThemeData(color: inkGreen),
      title: Text(
        materiel.name,
        style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        children: [
          MaterielForm(
            materiel: materiel,
            repository: repository,
            pickImage: pickImage,
            storeImage: storeImage,
            onSaved: () => Navigator.pop(context, true),
            onDeleted: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ),
  );
}

/// The equipment form. Creates a new equipment when [materiel] is `null`,
/// otherwise modifies it and offers to delete it.
class MaterielForm extends StatefulWidget {
  const MaterielForm({
    super.key,
    required this.repository,
    required this.onSaved,
    this.materiel,
    this.onDeleted,
    this.pickImage = _pickFromDevice,
    this.storeImage = storeMaterielImage,
  });

  final Materiel? materiel;
  final MaterielRepository repository;
  final VoidCallback onSaved;
  final VoidCallback? onDeleted;
  final MaterielImagePicker pickImage;
  final Future<String> Function(String sourcePath, String id) storeImage;

  @override
  State<MaterielForm> createState() => _MaterielFormState();
}

class _MaterielFormState extends State<MaterielForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.materiel?.name);
  late final _brand = TextEditingController(text: widget.materiel?.brand);
  late final _model = TextEditingController(text: widget.materiel?.model);
  late final _serial = TextEditingController(
    text: widget.materiel?.serialNumber,
  );
  late final _price = TextEditingController(
    text: widget.materiel?.purchasePrice.toStringAsFixed(2),
  );
  late MaterielCategory? _category = widget.materiel?.category;
  late DateTime? _purchaseDate = widget.materiel?.purchaseDate;
  late MaterielCondition? _condition = widget.materiel?.condition;
  late MaterielStatus _status =
      widget.materiel?.status ?? MaterielStatus.available;

  /// Path shown in the form: the saved photo, or a newly picked one.
  late String? _imagePath = widget.materiel?.imagePath;
  bool _saving = false;

  bool get _isEditing => widget.materiel != null;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    _price.dispose();
    super.dispose();
  }

  double? get _parsedPrice =>
      double.tryParse(_price.text.trim().replaceAll(',', '.'));

  Future<void> _chooseImage() async {
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
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Retirer l'image"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _imagePath = null);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final path = await widget.pickImage(source);
      if (path != null && mounted) setState(() => _imagePath = path);
    } catch (_) {
      _showMessage(
        "Impossible d'ouvrir ${source == ImageSource.camera ? 'la caméra' : 'la galerie'}.",
      );
    }
  }

  Future<void> _choosePurchaseDate(FormFieldState<DateTime> field) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(1970),
      lastDate: now,
      helpText: "Date d'achat",
      cancelText: 'Annuler',
      confirmText: 'OK',
    );
    if (picked == null || !mounted) return;
    setState(() => _purchaseDate = picked);
    field.didChange(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final id =
        widget.materiel?.id ??
        'materiel-${DateTime.now().millisecondsSinceEpoch}';
    final oldImage = widget.materiel?.imagePath;
    final name = _name.text.trim();
    try {
      var imagePath = _imagePath;
      if (imagePath != null && imagePath != oldImage) {
        imagePath = await widget.storeImage(imagePath, id);
      }
      await widget.repository.saveMateriel(
        Materiel(
          id: id,
          name: name,
          category: _category!,
          brand: _brand.text.trim(),
          model: _model.text.trim(),
          serialNumber: _serial.text.trim(),
          purchaseDate: _purchaseDate!,
          purchasePrice: _parsedPrice!,
          condition: _condition!,
          status: _status,
          imagePath: imagePath,
        ),
      );
      if (oldImage != null && oldImage != imagePath) {
        await deleteMaterielImage(oldImage);
      }
      if (!mounted) return;
      _showMessage(
        _isEditing
            ? 'Matériel « $name » modifié.'
            : 'Matériel « $name » enregistré.',
      );
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage("Impossible d'enregistrer le matériel. Réessayez.");
    }
  }

  Future<void> _delete() async {
    final materiel = widget.materiel!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le matériel ?'),
        content: Text('« ${materiel.name} » sera supprimé définitivement.'),
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
      await widget.repository.deleteMateriel(materiel);
      if (!mounted) return;
      _showMessage('Matériel « ${materiel.name} » supprimé.');
      widget.onDeleted?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Impossible de supprimer le matériel. Réessayez.');
    }
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Nom du matériel
          _field(
            _name,
            'Nom du matériel',
            'ex. Tracteur principal',
            Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          // 2. Catégorie
          DropdownButtonFormField<MaterielCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: _decoration('Catégorie', Icons.category_outlined),
            validator: (value) =>
                value == null ? 'Choisissez une catégorie' : null,
            items: [
              for (final category in MaterielCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(category.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 14),
          // 3. Marque
          _field(_brand, 'Marque', 'ex. John Deere', Icons.business_outlined),
          const SizedBox(height: 14),
          // 4. Modèle
          _field(
            _model,
            'Modèle',
            'ex. 5075E',
            Icons.precision_manufacturing_outlined,
          ),
          const SizedBox(height: 14),
          // 5. Numéro de série
          _field(
            _serial,
            'Numéro de série',
            'ex. JD5075E-2023-001',
            Icons.qr_code_2_rounded,
            capitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),
          // 6. Date d'achat
          FormField<DateTime>(
            initialValue: _purchaseDate,
            validator: (_) =>
                _purchaseDate == null ? "Choisissez la date d'achat" : null,
            builder: (field) => InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _choosePurchaseDate(field),
              child: InputDecorator(
                decoration: _decoration(
                  "Date d'achat",
                  Icons.event_outlined,
                ).copyWith(errorText: field.errorText),
                isEmpty: _purchaseDate == null,
                child: Text(
                  _purchaseDate == null
                      ? ''
                      : formatMaterielDate(_purchaseDate!),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 7. Prix d'achat (DT)
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (_required(value) != null) return 'Champ obligatoire';
              final price = _parsedPrice;
              if (price == null || price < 0) return 'Prix invalide';
              return null;
            },
            decoration: _decoration(
              "Prix d'achat (DT)",
              Icons.payments_outlined,
            ).copyWith(hintText: 'ex. 85000', suffixText: 'DT'),
          ),
          const SizedBox(height: 14),
          // 8. État du matériel
          DropdownButtonFormField<MaterielCondition>(
            initialValue: _condition,
            decoration: _decoration(
              'État du matériel',
              Icons.health_and_safety_outlined,
            ),
            validator: (value) => value == null ? "Choisissez l'état" : null,
            items: [
              for (final condition in MaterielCondition.values)
                DropdownMenuItem(
                  value: condition,
                  child: Text(condition.label),
                ),
            ],
            onChanged: (value) => setState(() => _condition = value),
          ),
          const SizedBox(height: 14),
          // 9. Statut
          DropdownButtonFormField<MaterielStatus>(
            initialValue: _status,
            decoration: _decoration('Statut', Icons.toggle_on_outlined),
            items: [
              for (final status in MaterielStatus.values)
                DropdownMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: materielStatusColor(status),
                      ),
                      const SizedBox(width: 8),
                      Text(status.label),
                    ],
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          ),
          const SizedBox(height: 18),
          // 10. Image du matériel
          const Text(
            'Image du matériel',
            style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _ImagePickerCard(imagePath: _imagePath, onTap: _chooseImage),
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: forestGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_isEditing ? Icons.save_outlined : Icons.add),
              label: Text(
                _isEditing ? 'Modifier' : 'Enregistrer le matériel',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    TextCapitalization capitalization = TextCapitalization.words,
  }) => TextFormField(
    controller: controller,
    validator: _required,
    textCapitalization: capitalization,
    decoration: _decoration(label, icon).copyWith(hintText: hint),
  );
}

class _MaterielTile extends StatelessWidget {
  const _MaterielTile({required this.materiel, required this.onTap});

  final Materiel materiel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = materiel.imagePath;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borderGreen),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFEAF6E5),
          foregroundImage: image == null ? null : FileImage(File(image)),
          child: Icon(
            materielCategoryIcon(materiel.category),
            color: forestGreen,
          ),
        ),
        title: Text(
          materiel.name,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.circle,
              size: 10,
              color: materielStatusColor(materiel.status),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${materiel.status.label} · ${materiel.brand}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: mutedGreen),
        onTap: onTap,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: inkGreen,
      fontSize: 18,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(icon, color: mutedGreen, size: 44),
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

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({required this.imagePath, required this.onTap});

  final String? imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderGreen),
          ),
          child: path == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_outlined, size: 40, color: forestGreen),
                    SizedBox(height: 10),
                    Text(
                      'Ajouter une image du matériel',
                      style: TextStyle(
                        color: inkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Caméra ou galerie'),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 40),
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.edit, color: Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
