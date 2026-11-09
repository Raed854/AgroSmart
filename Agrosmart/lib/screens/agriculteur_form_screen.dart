import 'package:flutter/material.dart';

import '../main.dart';
import '../models/agriculteur_model.dart';
import '../models/exploitation_model.dart';
import '../services/agriculteur_service.dart';
import '../widgets/brand_header.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

/// Add/edit form for a farmer profile and the exploitation linked to it.
/// Pass an existing [agriculteur] to edit it; omit it to create a new one.
class AgriculteurFormScreen extends StatefulWidget {
  const AgriculteurFormScreen({super.key, this.agriculteur});

  final Agriculteur? agriculteur;

  @override
  State<AgriculteurFormScreen> createState() => _AgriculteurFormScreenState();
}

class _AgriculteurFormScreenState extends State<AgriculteurFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AgriculteurService();

  late final _firstNameController = TextEditingController(
    text: widget.agriculteur?.firstName,
  );
  late final _lastNameController = TextEditingController(
    text: widget.agriculteur?.lastName,
  );
  late final _phoneController = TextEditingController(
    text: widget.agriculteur?.phone,
  );
  late final _emailController = TextEditingController(
    text: widget.agriculteur?.email,
  );
  late final _addressController = TextEditingController(
    text: widget.agriculteur?.address,
  );
  late final _exploitationNameController = TextEditingController(
    text: widget.agriculteur?.exploitation?.name,
  );
  late final _locationController = TextEditingController(
    text: widget.agriculteur?.exploitation?.location,
  );
  late final _sizeController = TextEditingController(
    text: widget.agriculteur?.exploitation?.sizeHectares.toString(),
  );
  late final _mainCropController = TextEditingController(
    text: widget.agriculteur?.exploitation?.mainCrop,
  );

  bool get _isEditing => widget.agriculteur != null;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _exploitationNameController.dispose();
    _locationController.dispose();
    _sizeController.dispose();
    _mainCropController.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Exploitation? exploitation = widget.agriculteur?.exploitation;
    final exploitationName = _exploitationNameController.text.trim();
    if (exploitationName.isNotEmpty) {
      exploitation = (exploitation ?? const Exploitation(
        name: '',
        location: '',
        sizeHectares: 0,
        mainCrop: '',
      )).copyWith(
        name: exploitationName,
        location: _locationController.text.trim(),
        sizeHectares: double.tryParse(_sizeController.text.trim()) ?? 0,
        mainCrop: _mainCropController.text.trim(),
      );
    }

    final agriculteur = Agriculteur(
      id: widget.agriculteur?.id ?? _service.nouvelId(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      exploitation: exploitation,
      archived: widget.agriculteur?.archived ?? false,
    );

    setState(() => _saving = true);
    if (_isEditing) {
      await _service.modifier(agriculteur);
    } else {
      await _service.ajouter(agriculteur);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: inkGreen),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandHeader(compact: true),
                const SizedBox(height: 28),
                Text(
                  _isEditing ? 'Edit farmer profile' : 'Add a farmer',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Register the farmer and, optionally, the exploitation '
                  'they are responsible for.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Farmer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _firstNameController,
                  label: 'First name',
                  hint: 'e.g. Omar',
                  icon: Icons.person_outline_rounded,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a first name'
                      : null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _lastNameController,
                  label: 'Last name',
                  hint: 'e.g. Belkacem',
                  icon: Icons.person_outline_rounded,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a last name'
                      : null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  hint: 'e.g. +216 20 123 456',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a phone number'
                      : null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email address',
                  hint: 'Optional',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return value.contains('@') ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Optional',
                  icon: Icons.location_on_outlined,
                  validator: (_) => null,
                ),
                const SizedBox(height: 28),
                Text(
                  'Exploitation (optional)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _exploitationNameController,
                  label: 'Exploitation name',
                  hint: 'e.g. Green Valley Farm',
                  icon: Icons.business_outlined,
                  validator: (_) => null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'e.g. Béja',
                  icon: Icons.map_outlined,
                  validator: (_) => null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _sizeController,
                  label: 'Size (ha)',
                  hint: 'e.g. 12.5',
                  icon: Icons.straighten_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return double.tryParse(value.trim()) == null
                        ? 'Enter a valid number'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _mainCropController,
                  label: 'Main crop',
                  hint: 'e.g. Wheat',
                  icon: Icons.grass_rounded,
                  validator: (_) => null,
                ),
                const SizedBox(height: 28),
                CustomButton(
                  label: _isEditing ? 'Save changes' : 'Add farmer',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
