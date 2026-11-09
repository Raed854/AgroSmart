import 'package:flutter/material.dart';

import '../main.dart';
import '../models/agriculteur_model.dart';
import '../services/agriculteur_service.dart';
import '../widgets/brand_header.dart';
import 'agriculteur_detail_screen.dart';
import 'agriculteur_form_screen.dart';

class AgriculteursScreen extends StatefulWidget {
  const AgriculteursScreen({super.key});

  @override
  State<AgriculteursScreen> createState() => _AgriculteursScreenState();
}

class _AgriculteursScreenState extends State<AgriculteursScreen> {
  final _service = AgriculteurService();
  bool _showArchived = false;
  bool _loading = true;
  List<Agriculteur> _agriculteurs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final agriculteurs = await _service.getAll(
      includeArchived: _showArchived,
    );
    if (!mounted) return;
    setState(() {
      _agriculteurs = agriculteurs;
      _loading = false;
    });
  }

  Future<void> _toggleShowArchived() async {
    _showArchived = !_showArchived;
    await _load();
  }

  Future<void> _openForm({Agriculteur? agriculteur}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgriculteurFormScreen(agriculteur: agriculteur),
      ),
    );
    await _load();
  }

  Future<void> _openDetail(Agriculteur agriculteur) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgriculteurDetailScreen(agriculteurId: agriculteur.id),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text('Agriculteurs', style: TextStyle(color: inkGreen)),
        iconTheme: const IconThemeData(color: inkGreen),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            onPressed: _toggleShowArchived,
            icon: Icon(
              _showArchived ? Icons.archive_rounded : Icons.archive_outlined,
              color: inkGreen,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: forestGreen,
        onPressed: () => _openForm(),
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: forestGreen),
              )
            : ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
          children: [
            const BrandHeader(compact: true),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: forestGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: .16),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Manage every farmer profile and the exploitation '
                      'they run.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_agriculteurs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text('No farmer profile yet. Tap + to add one.'),
                ),
              )
            else
              ..._agriculteurs.map(
                (agriculteur) => Card(
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
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFEAF6E5),
                      child: Icon(
                        Icons.person_rounded,
                        color: agriculteur.archived ? mutedGreen : forestGreen,
                      ),
                    ),
                    title: Text(
                      agriculteur.fullName,
                      style: TextStyle(
                        color: agriculteur.archived ? mutedGreen : inkGreen,
                        fontWeight: FontWeight.w800,
                        decoration: agriculteur.archived
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      agriculteur.exploitation != null
                          ? '${agriculteur.exploitation!.name}  •  '
                              '${agriculteur.exploitation!.sizeHectares} ha'
                          : 'No exploitation linked',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: mutedGreen,
                    ),
                    onTap: () => _openDetail(agriculteur),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
