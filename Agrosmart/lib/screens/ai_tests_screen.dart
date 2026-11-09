import 'package:flutter/material.dart';

import '../main.dart';
import '../models/ai_test.dart';
import '../services/ai_test_repository.dart';
import '../widgets/diagnosis_card.dart';

/// The list of saved Drone AI tests. Tapping a name opens its data.
class AiTestsScreen extends StatefulWidget {
  const AiTestsScreen({super.key, required this.repository});

  final AiTestRepository repository;

  @override
  State<AiTestsScreen> createState() => _AiTestsScreenState();
}

class _AiTestsScreenState extends State<AiTestsScreen> {
  List<AiTest>? _tests;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tests = await widget.repository.fetchTests();
      if (mounted) setState(() => _tests = tests);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de charger les tests.');
    }
  }

  Future<void> _open(AiTest test) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AiTestDetailScreen(test: test, repository: widget.repository),
      ),
    );
    if (deleted == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tests = _tests;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: const Text(
          'Tests enregistrés',
          style: TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!))
            : tests == null
            ? const Center(child: CircularProgressIndicator())
            : tests.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucun test enregistré.\n'
                    'Lancez « Test AI » puis « Enregistrer le test ».',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: mutedGreen),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  for (final test in tests)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: borderGreen),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: test.diseasedCount > 0
                              ? const Color(0xFFFBE9E7)
                              : const Color(0xFFEAF6E5),
                          child: Icon(
                            Icons.biotech_outlined,
                            color: test.diseasedCount > 0
                                ? const Color(0xFFD84315)
                                : forestGreen,
                          ),
                        ),
                        title: Text(
                          test.name,
                          style: const TextStyle(
                            color: inkGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${formatDate(test.date)}'
                          '${test.droneName == null ? '' : ' · ${test.droneName}'}'
                          '\n${_summary(test)}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _open(test),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

String _summary(AiTest test) {
  if (test.analysedCount == 0)
    return '${test.images.length} image(s), non analysées';
  final diseased = test.diseasedCount;
  return '${test.images.length} image(s) · '
      '${diseased == 0 ? 'toutes saines' : '$diseased malade(s)'}';
}

/// All the data saved for one test.
class AiTestDetailScreen extends StatelessWidget {
  const AiTestDetailScreen({
    super.key,
    required this.test,
    required this.repository,
  });

  final AiTest test;
  final AiTestRepository repository;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le test ?'),
        content: Text('« ${test.name} » sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repository.deleteTest(test.id);
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkGreen),
        title: Text(
          test.name,
          style: const TextStyle(color: inkGreen, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Supprimer',
            onPressed: () => _delete(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: forestGreen,
                borderRadius: BorderRadius.circular(22),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(Icons.badge_outlined, 'Nom', test.name),
                    _InfoRow(
                      Icons.calendar_today_outlined,
                      'Date',
                      formatDate(test.date),
                    ),
                    _InfoRow(
                      Icons.flight_rounded,
                      'Drone',
                      test.droneName ?? '—',
                    ),
                    _InfoRow(
                      Icons.biotech_outlined,
                      'Résultat',
                      _summary(test),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < test.images.length; i++)
              DiagnosisCard(
                index: i + 1,
                image: test.images[i].image,
                diagnosis: test.images[i].diagnosis,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
