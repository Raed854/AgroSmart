// Formulaire mouvement (entrée / sortie) – module 3.6
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/stock_batch.dart';
import '../models/stock_movement.dart';
import '../models/stock_product.dart';
import '../services/stock_service.dart';
import '../utils/unit_converter.dart';
import '../widgets/custom_button.dart';

class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({super.key, required this.product});
  final StockProduct product;

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = StockService.instance;

  MovementType _type = MovementType.sortie;
  final _quantityCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  StockBatch? _selectedBatch;
  StockBatch? _suggestedBatch;
  List<StockBatch> _batches = [];
  bool _saving = false;

  /// Unité dans laquelle l'utilisateur saisit la quantité.
  /// Peut être différente de l'unité du produit si la famille est convertible.
  late String _inputUnit;

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _inputUnit = widget.product.unit; // unité par défaut = unité du produit
    _loadBatches();
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    final batches = await _service.getBatchesForProduct(widget.product.id!);
    final suggested =
        await _service.getFefoSuggestedBatch(widget.product.id!);
    if (!mounted) return;

    final available = batches.where((b) => b.quantity > 0).toList();

    // On cherche l'instance qui vient de _batches (même id) pour éviter
    // l'AssertionError du DropdownButtonFormField (valeur absente des items)
    StockBatch? selectedFromList;
    if (_type == MovementType.sortie && suggested != null) {
      selectedFromList = available.firstWhere(
        (b) => b.id == suggested.id,
        orElse: () => available.isNotEmpty ? available.first : suggested,
      );
    }

    setState(() {
      _batches = available;
      _suggestedBatch = selectedFromList;
      _selectedBatch = selectedFromList;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Date du mouvement',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final rawQty = double.parse(_quantityCtrl.text.replaceAll(',', '.'));
      // Convertit vers l'unité du produit avant enregistrement
      final qty = UnitConverter.canConvert(_inputUnit, widget.product.unit)
          ? UnitConverter.convert(rawQty, _inputUnit, widget.product.unit)
          : rawQty;
      await _service.recordMovement(
        StockMovement(
          productId: widget.product.id!,
          batchId: _selectedBatch?.id,
          type: _type,
          quantity: qty,
          date: _date,
          note:
              _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ),
      );
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
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
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
          'Mouvement · ${widget.product.name}',
          style: const TextStyle(
            color: inkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
            children: [
              // ── Résumé stock actuel ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      const Border.fromBorderSide(BorderSide(color: borderGreen)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: forestGreen),
                    const SizedBox(width: 12),
                    Text(
                      'Stock actuel : ${UnitConverter.smartDisplay(widget.product.totalQuantity, widget.product.unit)}',
                      style: const TextStyle(
                        color: inkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Type ──
              const Text(
                'Type de mouvement',
                style: TextStyle(
                  color: inkGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _typeButton(
                      'Entrée',
                      Icons.add_circle_outline_rounded,
                      MovementType.entree,
                      const Color(0xFF2E7D32),
                      const Color(0xFFE8F5E9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _typeButton(
                      'Sortie',
                      Icons.remove_circle_outline_rounded,
                      MovementType.sortie,
                      const Color(0xFFC62828),
                      const Color(0xFFFCE4EC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Quantité ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantité',
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Quantité requise';
                        }
                        final n = double.tryParse(v.replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Quantité > 0 requise';
                        if (_type == MovementType.sortie) {
                          // Convertit dans l'unité du produit pour comparer
                          final inProductUnit =
                              UnitConverter.canConvert(_inputUnit, widget.product.unit)
                                  ? UnitConverter.convert(n, _inputUnit, widget.product.unit)
                                  : n;
                          if (inProductUnit > widget.product.totalQuantity) {
                            return 'Stock insuffisant (${UnitConverter.smartDisplay(widget.product.totalQuantity, widget.product.unit)})';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  // Sélecteur d'unité de saisie (visible seulement si famille convertible)
                  if (UnitConverter.siblingUnits(widget.product.unit).length > 1) ...[
                    const SizedBox(width: 10),
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderGreen),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _inputUnit,
                          items: UnitConverter.siblingUnits(widget.product.unit)
                              .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(
                                      u,
                                      style: const TextStyle(
                                        color: inkGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (u) =>
                              setState(() => _inputUnit = u!),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Indication de conversion si unité ≠ unité produit
              if (_inputUnit != widget.product.unit &&
                  _quantityCtrl.text.isNotEmpty)
                Builder(builder: (_) {
                  final raw = double.tryParse(
                      _quantityCtrl.text.replaceAll(',', '.'));
                  if (raw == null || raw <= 0) return const SizedBox.shrink();
                  final converted = UnitConverter.convert(
                      raw, _inputUnit, widget.product.unit);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '→ ${UnitConverter.smartDisplay(converted, widget.product.unit)} dans l\'unité du produit',
                      style: const TextStyle(
                        color: forestGreen,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),

              // ── Date ──
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
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
                    suffixIcon: const Icon(
                      Icons.calendar_month_outlined,
                      color: mutedGreen,
                    ),
                  ),
                  child: Text(
                    _dateFormat.format(_date),
                    style: const TextStyle(color: inkGreen),
                  ),
                ),
              ),

              // ── Lot ──
              if (_batches.isNotEmpty) ...[
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Lot (optionnel)',
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
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<StockBatch?>(
                      value: _selectedBatch,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<StockBatch?>(
                          value: null,
                          child: Text('Aucun lot spécifique'),
                        ),
                        ..._batches.map(
                          (b) => DropdownMenuItem<StockBatch?>(
                            value: b,
                            child: Text(
                              '${b.batchNumber} (${UnitConverter.smartDisplay(b.quantity, widget.product.unit)})'
                              '${b.id == _suggestedBatch?.id && _type == MovementType.sortie ? '  ★ FEFO' : ''}',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedBatch = v),
                    ),
                  ),
                ),
                if (_type == MovementType.sortie && _suggestedBatch != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '★ Lot "${_suggestedBatch!.batchNumber}" suggéré — expire en premier (FEFO).',
                      style: const TextStyle(
                        color: forestGreen,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),

              // ── Note ──
              TextFormField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Motif / note (optionnel)',
                  hintText: 'ex. Semis parcelle 3…',
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
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Enregistrer le mouvement',
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeButton(
    String label,
    IconData icon,
    MovementType type,
    Color fg,
    Color bg,
  ) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
          if (type == MovementType.sortie && _suggestedBatch != null) {
            // _suggestedBatch vient déjà de _batches — instance correcte
            _selectedBatch = _suggestedBatch;
          } else if (type == MovementType.entree) {
            _selectedBatch = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? fg : borderGreen,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? fg : mutedGreen),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? fg : mutedGreen,
                fontWeight: selected ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
