import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/drone.dart';
import '../services/drone_repository.dart';
import '../widgets/drone_visuals.dart';
import 'drones_screen.dart';

/// Returns the path of a picked photo, or `null` if the farmer cancelled.
typedef DroneImagePicker = Future<String?> Function(ImageSource source);

Future<String?> _pickFromDevice(ImageSource source) async =>
    (await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    ))?.path;

/// Creates or edits a drone profile.
class DroneFormScreen extends StatefulWidget {
  const DroneFormScreen({
    super.key,
    this.repository,
    this.drone,
    this.pickImage = _pickFromDevice,
    this.storeImage = storeDroneImage,
    this.showDroneListButton = true,
  });

  /// `null` to create a new drone.
  final Drone? drone;

  /// Shows the "Mes drones" button that opens the list of saved drones.
  /// Turned off when the form is opened from that list.
  final bool showDroneListButton;

  /// Defaults to the local sqflite database.
  final DroneRepository? repository;
  final DroneImagePicker pickImage;
  final Future<String> Function(String sourcePath, String droneId) storeImage;

  @override
  State<DroneFormScreen> createState() => _DroneFormScreenState();
}

class _DroneFormScreenState extends State<DroneFormScreen> {
  late final DroneRepository _repository =
      widget.repository ?? SqfliteDroneRepository();
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.drone?.name);
  late final _brand = TextEditingController(text: widget.drone?.brand);
  late final _model = TextEditingController(text: widget.drone?.model);
  late DroneType? _type = widget.drone?.type;
  late DroneStatus _status = widget.drone?.status ?? DroneStatus.active;

  /// Path shown in the form: the saved photo, or a newly picked one.
  late String? _imagePath = widget.drone?.imagePath;
  bool _saving = false;

  bool get _isEditing => widget.drone != null;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    super.dispose();
  }

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
                title: const Text('Retirer la photo'),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final id =
        widget.drone?.id ?? 'drone-${DateTime.now().millisecondsSinceEpoch}';
    final oldImage = widget.drone?.imagePath;
    try {
      var imagePath = _imagePath;
      if (imagePath != null && imagePath != oldImage) {
        imagePath = await widget.storeImage(imagePath, id);
      }
      await _repository.saveDrone(
        Drone(
          id: id,
          name: _name.text.trim(),
          brand: _brand.text.trim(),
          model: _model.text.trim(),
          type: _type!,
          status: _status,
          imagePath: imagePath,
        ),
      );
      if (oldImage != null && oldImage != imagePath) {
        await deleteDroneImage(oldImage);
      }
      if (!mounted) return;
      _showMessage(
        _isEditing
            ? 'Drone « ${_name.text.trim()} » enregistré.'
            : 'Drone « ${_name.text.trim()} » créé.',
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage("Impossible d'enregistrer le drone. Réessayez.");
    }
  }

  Future<void> _delete() async {
    final drone = widget.drone!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le drone ?'),
        content: Text('Le profil « ${drone.name} » sera supprimé.'),
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
      await _repository.deleteDrone(drone);
      if (!mounted) return;
      _showMessage('Drone « ${drone.name} » supprimé.');
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Impossible de supprimer le drone. Réessayez.');
    }
  }

  void _openDroneList() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DronesScreen(repository: _repository)),
  );

  bool get _showListButton => widget.showDroneListButton && !_isEditing;

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: Text(
          _isEditing ? 'Modifier le drone' : 'Nouveau drone',
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_showListButton)
            IconButton(
              tooltip: 'Mes drones',
              onPressed: _openDroneList,
              icon: const Icon(Icons.list_alt_rounded),
            ),
          if (_isEditing)
            IconButton(
              tooltip: 'Supprimer le drone',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            children: [
              if (_showListButton) ...[
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _openDroneList,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: forestGreen,
                      side: const BorderSide(color: forestGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text(
                      'Mes drones enregistrés',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              _ImagePickerCard(imagePath: _imagePath, onTap: _chooseImage),
              const SizedBox(height: 22),
              _field(
                _name,
                'Nom du drone',
                'ex. AgroDrone X2',
                Icons.badge_outlined,
              ),
              const SizedBox(height: 14),
              _field(_brand, 'Marque', 'ex. DJI', Icons.business_outlined),
              const SizedBox(height: 14),
              _field(
                _model,
                'Modèle',
                'ex. Mavic 3M',
                Icons.precision_manufacturing_outlined,
              ),
              const SizedBox(height: 22),
              const _SectionLabel('Type de drone'),
              const SizedBox(height: 10),
              FormField<DroneType>(
                initialValue: _type,
                validator: (_) =>
                    _type == null ? 'Choisissez un type de drone' : null,
                builder: (state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final type in DroneType.values)
                          ChoiceChip(
                            avatar: Icon(droneTypeIcon(type), size: 18),
                            label: Text(type.label),
                            selected: _type == type,
                            onSelected: (_) {
                              setState(() => _type = type);
                              state.didChange(type);
                            },
                          ),
                      ],
                    ),
                    if (state.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          state.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('État'),
              const SizedBox(height: 10),
              SegmentedButton<DroneStatus>(
                segments: [
                  for (final status in DroneStatus.values)
                    ButtonSegment(
                      value: status,
                      label: Text(status.label),
                      icon: Icon(
                        Icons.circle,
                        size: 12,
                        color: droneStatusColor(status),
                      ),
                    ),
                ],
                selected: {_status},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => _status = selection.single),
              ),
              const SizedBox(height: 30),
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
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isEditing ? 'Enregistrer' : 'Créer le drone',
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
                      'Supprimer le drone',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
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

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
  ) => TextFormField(
    controller: controller,
    validator: _required,
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
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
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: inkGreen,
      fontSize: 16,
      fontWeight: FontWeight.w800,
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
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderGreen),
          ),
          child: path == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 40,
                      color: forestGreen,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Ajouter une image du drone',
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
                    Positioned(
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
