import 'package:flutter/material.dart';

import '../main.dart';
import '../models/ai_test.dart';
import '../models/drone.dart';
import '../services/ai_test_repository.dart';
import '../services/drone_ai_service.dart';
import '../services/drone_repository.dart';
import '../widgets/diagnosis_card.dart';
import 'ai_tests_screen.dart';
import 'drones_screen.dart';

/// Shows 3 drone pictures from the image server, sends them to the plant
/// disease AI model and saves the test (name, date, drone, results).
class DroneAiScreen extends StatefulWidget {
  const DroneAiScreen({
    super.key,
    this.service,
    this.droneRepository,
    this.testRepository,
  });

  final DroneAiService? service;
  final DroneRepository? droneRepository;
  final AiTestRepository? testRepository;

  @override
  State<DroneAiScreen> createState() => _DroneAiScreenState();
}

class _DroneAiScreenState extends State<DroneAiScreen> {
  static const _slots = 3;

  late final DroneAiService _service = widget.service ?? DroneAiService();
  late final DroneRepository _droneRepository =
      widget.droneRepository ?? SqfliteDroneRepository();
  late final AiTestRepository _testRepository =
      widget.testRepository ?? SqfliteAiTestRepository();

  final _nameController = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  List<Drone>? _drones;
  Drone? _selectedDrone;

  List<DroneImage> _images = const [];

  /// Same order as [_images]; `null` while not analysed yet.
  List<DiseaseDiagnosis?> _results = const [];
  bool _loadingImages = false;
  bool _analysing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrones();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadDrones() async {
    try {
      final drones = await _droneRepository.fetchDrones();
      if (!mounted) return;
      setState(() {
        _drones = drones;
        if (!drones.any((d) => d.id == _selectedDrone?.id)) {
          _selectedDrone = drones.length == 1 ? drones.first : null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _drones = const []);
    }
  }

  Future<void> _manageDrones() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DronesScreen()),
    );
    await _loadDrones();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _date = date);
  }

  void _openTests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiTestsScreen(repository: _testRepository),
      ),
    );
  }

  Future<void> _loadImages() async {
    setState(() {
      _loadingImages = true;
      _error = null;
    });
    try {
      final images = await _service.fetchImages();
      if (!mounted) return;
      setState(() {
        _images = images;
        _results = List.filled(images.length, null);
      });
    } on DroneAiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _testAi() async {
    setState(() {
      _analysing = true;
      _error = null;
      _results = List.filled(_images.length, null);
    });
    try {
      for (var i = 0; i < _images.length; i++) {
        final diagnosis = await _service.diagnose(_images[i]);
        if (!mounted) return;
        setState(() => _results = [..._results]..[i] = diagnosis);
      }
    } on DroneAiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _analysing = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final drones = _drones ?? const [];
    final String? problem = name.isEmpty
        ? 'Donnez un nom au test.'
        : drones.isNotEmpty && _selectedDrone == null
        ? 'Choisissez le drone du test.'
        : _images.isEmpty
        ? 'Chargez d’abord les images du drone.'
        : null;
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    setState(() => _saving = true);
    try {
      await _testRepository.saveTest(
        AiTest(
          id: 'test-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          date: _date,
          droneId: _selectedDrone?.id,
          droneName: _selectedDrone?.name,
          images: [
            for (var i = 0; i < _images.length; i++)
              AiTestImage(image: _images[i], diagnosis: _results[i]),
          ],
        ),
      );
      if (!mounted) return;
      _nameController.clear();
      setState(() {
        _images = const [];
        _results = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test « $name » enregistré.'),
          action: SnackBarAction(label: 'Voir', onPressed: _openTests),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible d’enregistrer le test.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loadingImages || _analysing || _saving;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: const Text(
          'Drone AI',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Tests enregistrés',
            onPressed: _openTests,
            icon: const Icon(Icons.list_alt_rounded, color: inkGreen),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const _SectionTitle('Nouveau test'),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration(
                'Nom du test',
                Icons.badge_outlined,
                hint: 'Ex. Parcelle nord – tomates',
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: _fieldDecoration(
                  'Date du test',
                  Icons.calendar_today_outlined,
                ),
                child: Text(
                  formatDate(_date),
                  style: const TextStyle(color: inkGreen, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Drones')),
                TextButton.icon(
                  onPressed: _manageDrones,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Gérer'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _DroneList(
              drones: _drones,
              selected: _selectedDrone,
              onSelect: (drone) => setState(() => _selectedDrone = drone),
              onAdd: _manageDrones,
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Images du drone'),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < _slots; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _ImageSlot(
                      image: i < _images.length ? _images[i] : null,
                      loading: _loadingImages,
                      onTap: i < _images.length
                          ? () => showImageDialog(context, _images[i])
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : _loadImages,
              style: _buttonStyle(forestGreen),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Résultats drone'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy || _images.isEmpty ? null : _testAi,
              style: _buttonStyle(freshGreen),
              icon: _analysing
                  ? const _ButtonSpinner()
                  : const Icon(Icons.biotech_outlined),
              label: Text(_analysing ? 'Analyse en cours…' : 'Test AI'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(message: _error!),
            ],
            if (_results.any((r) => r != null)) ...[
              const SizedBox(height: 24),
              const _SectionTitle('Résultats AI'),
              const SizedBox(height: 12),
              for (var i = 0; i < _images.length; i++)
                if (_results[i] != null)
                  DiagnosisCard(
                    index: i + 1,
                    image: _images[i],
                    diagnosis: _results[i],
                  ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy || _images.isEmpty ? null : _save,
              style: OutlinedButton.styleFrom(
                foregroundColor: forestGreen,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: forestGreen, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: _saving
                  ? const _ButtonSpinner(color: forestGreen)
                  : const Icon(Icons.save_outlined),
              label: const Text('Enregistrer le test'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: forestGreen),
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
  );

  ButtonStyle _buttonStyle(Color color) => FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

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

/// The farm's drones; tap one to make it the drone of the test.
class _DroneList extends StatelessWidget {
  const _DroneList({
    required this.drones,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final List<Drone>? drones;
  final Drone? selected;
  final ValueChanged<Drone> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final drones = this.drones;
    if (drones == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (drones.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderGreen),
        ),
        child: ListTile(
          leading: const Icon(Icons.flight_rounded, color: mutedGreen),
          title: const Text('Aucun drone'),
          subtitle: const Text('Créez un drone pour l’associer au test.'),
          trailing: const Icon(Icons.add_rounded, color: forestGreen),
          onTap: onAdd,
        ),
      );
    }
    return Column(
      children: [
        for (final drone in drones)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: drone.id == selected?.id
                ? const Color(0xFFEAF6E5)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: drone.id == selected?.id ? forestGreen : borderGreen,
                width: drone.id == selected?.id ? 1.5 : 1,
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.flight_rounded,
                  color: drone.status == DroneStatus.active
                      ? forestGreen
                      : mutedGreen,
                ),
              ),
              title: Text(
                drone.name,
                style: const TextStyle(
                  color: inkGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${drone.brand} ${drone.model} · ${drone.type.label} · '
                '${drone.status.label}',
              ),
              trailing: Icon(
                drone.id == selected?.id
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: forestGreen,
              ),
              onTap: () => onSelect(drone),
            ),
          ),
      ],
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({this.image, required this.loading, this.onTap});

  final DroneImage? image;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderGreen),
        ),
        child: InkWell(
          onTap: onTap,
          child: image != null
              ? Image.memory(image!.bytes, fit: BoxFit.cover)
              : Center(
                  child: loading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(
                          Icons.image_outlined,
                          color: mutedGreen,
                          size: 32,
                        ),
                ),
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
  }
}
