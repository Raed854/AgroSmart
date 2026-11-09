import 'package:flutter/material.dart';

import '../main.dart';
import '../services/parcelle_repository.dart';
import 'parcelles/parcelles_list_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _parcelleRepository = ParcelleRepository();
  
  int _parcelleCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final parcelleCount = await _parcelleRepository.count();
      
      setState(() {
        _parcelleCount = parcelleCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text(
          'AgroSmart AI',
          style: TextStyle(color: forestGreen, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh, color: inkGreen),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: const Icon(Icons.account_circle_outlined, color: inkGreen),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            const Text(
              'Bonjour, agriculteur 👋',
              style: TextStyle(
                color: inkGreen,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text('Voici votre ferme en un coup d\'œil aujourd\'hui.'),
            const SizedBox(height: 24),
            const Text(
              'Gestion de la ferme',
              style: TextStyle(
                color: inkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
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
                  backgroundColor: const Color(0xFFEAF6E5),
                  child: Icon(Icons.landscape_outlined, color: forestGreen),
                ),
                title: const Text(
                  'Parcelles',
                  style: TextStyle(
                    color: inkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  _isLoading
                      ? 'Chargement...'
                      : _parcelleCount == 0
                          ? 'Aucune parcelle'
                          : '$_parcelleCount parcelle${_parcelleCount > 1 ? 's' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParcellesListScreen(),
                    ),
                  );
                  // Reload data when returning from the screen
                  _loadDashboardData();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
