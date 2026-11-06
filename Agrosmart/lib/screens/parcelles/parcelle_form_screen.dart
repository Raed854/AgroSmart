import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../main.dart';
import '../../models/parcelle_model.dart';
import '../../services/parcelle_repository.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ParcelleFormScreen extends StatefulWidget {
  final ParcelleModel? parcelle;

  const ParcelleFormScreen({super.key, this.parcelle});

  @override
  State<ParcelleFormScreen> createState() => _ParcelleFormScreenState();
}

class _ParcelleFormScreenState extends State<ParcelleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _parcelleRepository = ParcelleRepository();
  final _uuid = const Uuid();

  late final TextEditingController _nomController;
  late final TextEditingController _surfaceController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  String _typeSol = typesSol.first;

  bool _isLoading = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.parcelle?.nom ?? '');
    _surfaceController = TextEditingController(
      text: widget.parcelle?.surface.toString() ?? '',
    );
    _latitudeController = TextEditingController(
      text: widget.parcelle?.latitude.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: widget.parcelle?.longitude.toString() ?? '',
    );
    _typeSol = widget.parcelle?.typeSol ?? typesSol.first;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _surfaceController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Vérifier les permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Les services de localisation sont désactivés');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission de localisation refusée');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Permission de localisation définitivement refusée. '
          'Veuillez l\'activer dans les paramètres',
        );
      }

      // Obtenir la position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position obtenue avec succès'),
            backgroundColor: forestGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _saveParcelle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final parcelle = ParcelleModel(
        id: widget.parcelle?.id ?? _uuid.v4(),
        nom: _nomController.text.trim(),
        surface: double.parse(_surfaceController.text.trim()),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
        typeSol: _typeSol,
        archivee: widget.parcelle?.archivee ?? false,
        createdAt: widget.parcelle?.createdAt ?? DateTime.now(),
      );

      if (widget.parcelle == null) {
        await _parcelleRepository.insert(parcelle);
      } else {
        await _parcelleRepository.update(parcelle);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'enregistrement: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.parcelle != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: Text(
          isEditing ? 'Modifier la parcelle' : 'Nouvelle parcelle',
          style: const TextStyle(color: inkGreen),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CustomTextField(
                controller: _nomController,
                label: 'Nom de la parcelle',
                hint: 'Ex: Champ Nord',
                icon: Icons.label_outline,
                validator: (value) => validateRequired(value, 'Le nom'),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _surfaceController,
                label: 'Surface (hectares)',
                hint: 'Ex: 5.5',
                icon: Icons.straighten_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: validateSurface,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _typeSol,
                decoration: InputDecoration(
                  labelText: 'Type de sol',
                  prefixIcon: const Icon(Icons.terrain, color: mutedGreen),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: borderGreen),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: borderGreen),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: forestGreen, width: 2),
                  ),
                ),
                items: typesSol
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _typeSol = value!),
              ),
              const SizedBox(height: 24),
              const Text(
                'Coordonnées GPS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: inkGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _latitudeController,
                      label: 'Latitude',
                      hint: 'Ex: 48.8566',
                      icon: Icons.location_on_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: validateLatitude,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _longitudeController,
                      label: 'Longitude',
                      hint: 'Ex: 2.3522',
                      icon: Icons.location_on_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: validateLongitude,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Utiliser ma position',
                outlined: true,
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                isLoading: _isLoadingLocation,
                icon: const Icon(Icons.my_location, size: 20),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: isEditing ? 'Enregistrer' : 'Créer la parcelle',
                onPressed: _isLoading ? null : _saveParcelle,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
