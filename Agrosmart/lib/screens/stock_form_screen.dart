// Formulaire ajout / modification d'un produit – module 3.6
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/stock_batch.dart';
import '../models/stock_product.dart';
import '../services/stock_service.dart';
import '../widgets/custom_button.dart';

class StockFormScreen extends StatefulWidget {
  const StockFormScreen({super.key, this.product});

  /// Si non null, on est en mode édition.
  final StockProduct? product;

  @override
  State<StockFormScreen> createState() => _StockFormScreenState();
}

class _StockFormScreenState extends State<StockFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = StockService.instance;

  late final _nameCtrl = TextEditingController(text: widget.product?.name);
  late final _quantityCtrl = TextEditingController(
    text: widget.product != null
        ? _fmt(widget.product!.totalQuantity)
        : '',
  );
  late final _thresholdCtrl = TextEditingController(
    text: widget.product != null ? _fmt(widget.product!.minThreshold) : '',
  );
  late final _notesCtrl =
      TextEditingController(text: widget.product?.notes ?? '');

  late ProductCategory _category =
      widget.product?.category ?? ProductCategory.semences;
  late String _unit = widget.product?.unit ?? 'kg';

  // Lot initial (uniquement à la création)
  final _batchCtrl = TextEditingController();
  DateTime? _expiryDate;

  bool _saving = false;
  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _thresholdCtrl.dispose();
    _notesCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: "Date d'expiration",
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Avertissement si date d'expiration déjà passée
    if (_expiryDate != null && _expiryDate!.isBefore(DateTime.now())) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Date déjà passée'),
          content: const Text(
            "La date d'expiration que vous avez saisie est déjà passée. Voulez-vous continuer quand même ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final updated = widget.product!.copyWith(
          name: _nameCtrl.text.trim(),
          category: _category,
          unit: _unit,
          minThreshold: double.parse(_thresholdCtrl.text),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        await _service.updateProduct(updated);
      } else {
        final qty = double.parse(_quantityCtrl.text);
        final product = await _service.addProduct(
          StockProduct(
            name: _nameCtrl.text.trim(),
            category: _category,
            unit: _unit,
            totalQuantity: 0,
            minThreshold: double.parse(_thresholdCtrl.text),
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        // Crée le lot initial si une quantité > 0
        if (qty > 0) {
          final batchNumber = _batchCtrl.text.trim().isEmpty
              ? 'LOT-${DateFormat('yyyyMMdd').format(DateTime.now())}'
              : _batchCtrl.text.trim();
          await _service.addBatch(
            StockBatch(
              productId: product.id!,
              batchNumber: batchNumber,
              quantity: qty,
              expiryDate: _expiryDate,
            ),
          );
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on StockServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: Text(
          _isEdit ? 'Modifier le produit' : 'Nouveau produit',
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
            children: [
              _sectionLabel('Informations générales'),
              const SizedBox(height: 12),
              _field(
                controller: _nameCtrl,
                label: 'Nom du produit',
                hint: 'ex. Semences de maïs hybride',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              _dropdownCategory(),
              const SizedBox(height: 16),
              _dropdownUnit(),
              const SizedBox(height: 16),
              _field(
                controller: _thresholdCtrl,
                label: 'Seuil minimal de stock',
                hint: 'ex. 10',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Seuil requis';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Nombre valide requis (≥ 0)';
                  return null;
                },
                suffix: _unit,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _notesCtrl,
                label: 'Notes (optionnel)',
                hint: 'Informations supplémentaires…',
                maxLines: 3,
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 24),
                _sectionLabel('Lot initial'),
                const SizedBox(height: 12),
                _field(
                  controller: _quantityCtrl,
                  label: 'Quantité initiale',
                  hint: 'ex. 50',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Quantité requise';
                    final n = double.tryParse(v);
                    if (n == null || n < 0) return 'Nombre ≥ 0 requis';
                    return null;
                  },
                  suffix: _unit,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _batchCtrl,
                  label: 'Numéro de lot (optionnel)',
                  hint: 'ex. MAIS-2401',
                ),
                const SizedBox(height: 16),
                _datePicker(),
              ],
              const SizedBox(height: 32),
              CustomButton(
                label: _isEdit ? 'Enregistrer' : 'Créer le produit',
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: inkGreen,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? suffix,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGreen),
        ),
      ),
      validator: validator,
    );
  }

  Widget _dropdownCategory() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Catégorie',
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGreen),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductCategory>(
          value: _category,
          isExpanded: true,
          items: ProductCategory.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
              .toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
      ),
    );
  }

  Widget _dropdownUnit() {
    const units = kStockUnits;
    final isCustom = !units.contains(_unit);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Unité de mesure',
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGreen),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: isCustom ? null : _unit,
          isExpanded: true,
          hint: isCustom ? Text(_unit) : null,
          items: units
              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
              .toList(),
          onChanged: (v) => setState(() => _unit = v!),
        ),
      ),
    );
  }

  Widget _datePicker() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Date d'expiration (optionnelle)",
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderGreen),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderGreen),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_expiryDate != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _expiryDate = null),
                ),
              const Icon(Icons.calendar_month_outlined, color: mutedGreen),
            ],
          ),
        ),
        child: Text(
          _expiryDate != null
              ? dateFormat.format(_expiryDate!)
              : 'Sélectionner une date',
          style: TextStyle(
            color: _expiryDate != null ? inkGreen : mutedGreen,
          ),
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
