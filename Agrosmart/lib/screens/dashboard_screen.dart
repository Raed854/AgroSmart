import 'package:flutter/material.dart';

import '../main.dart';
import 'cultures_screen.dart';
import 'irrigation_screen.dart';
import 'materiels_screen.dart';
import 'parcelles_screen.dart';
import 'profile_screen.dart';
import 'recoltes_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _DashboardAction(
        'Parcelles',
        '4 plots',
        Icons.landscape_outlined,
        const ParcellesScreen(),
      ),
      _DashboardAction(
        'Cultures',
        '8 active crops',
        Icons.grass_rounded,
        const CulturesScreen(),
      ),
      _DashboardAction(
        'Récoltes',
        'Next in 12 days',
        Icons.agriculture_rounded,
        const RecoltesScreen(),
      ),
      _DashboardAction(
        'Irrigation',
        'System ready',
        Icons.water_drop_outlined,
        const IrrigationScreen(),
      ),
      _DashboardAction(
        'Matériels',
        '6 equipment items',
        Icons.handyman_outlined,
        const MaterielsScreen(),
      ),
    ];

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
              'Good morning, farmer 👋',
              style: TextStyle(
                color: inkGreen,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text('Here is your farm at a glance today.'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: forestGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, color: Color(0xFFFFD66B), size: 34),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '24°C  •  Clear skies\nPerfect conditions for field work.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Farm management',
              style: TextStyle(
                color: inkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...actions.map(
              (action) => Card(
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
                    child: Icon(action.icon, color: forestGreen),
                  ),
                  title: Text(
                    action.title,
                    style: const TextStyle(
                      color: inkGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(action.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => action.screen),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAction {
  const _DashboardAction(this.title, this.subtitle, this.icon, this.screen);

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
}
