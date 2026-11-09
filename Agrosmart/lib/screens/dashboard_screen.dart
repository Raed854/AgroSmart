import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import 'drone_ai_screen.dart';
import 'drone_form_screen.dart';
import 'equipment_analytics_screen.dart';
import 'irrigation_planning_screen.dart';
import 'irrigation_screen.dart';
import 'maintenance_screen.dart';
import 'materiels_screen.dart';
import 'parcel_health_map_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final actions = [
      _DashboardAction(
        'Parcel Health Map',
        'AI anomaly detection',
        Icons.map_outlined,
        const ParcelHealthMapScreen(),
      ),
      _DashboardAction(
        'Irrigation',
        'Suivre les irrigations de vos parcelles',
        Icons.water_drop_outlined,
        const IrrigationScreen(),
      ),
      _DashboardAction(
        'Planning irrigation IA',
        "Planning adapté à la météo et à l'humidité",
        Icons.calendar_month_outlined,
        const IrrigationPlanningScreen(),
      ),
      _DashboardAction(
        'Drone',
        'Créer et gérer vos drones',
        Icons.flight_rounded,
        const DroneFormScreen(),
      ),
      _DashboardAction(
        'Drone AI',
        'Images du drone et diagnostic AI',
        Icons.biotech_outlined,
        const DroneAiScreen(),
      ),
      _DashboardAction(
        'Matériels',
        'Suivre vos équipements',
        Icons.handyman_outlined,
        const MaterielsScreen(),
      ),
      _DashboardAction(
        'Maintenance',
        "Carburant, maintenance et main d'œuvre",
        Icons.build_circle_outlined,
        const MaintenanceScreen(),
      ),
      _DashboardAction(
        'Statistiques & IA',
        'Carburant, maintenances prévues et durée de vie',
        Icons.insights_outlined,
        const EquipmentAnalyticsScreen(),
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
            Text(
              'Bonjour${user == null ? '' : ', ${user.name}'} 👋',
              style: TextStyle(
                color: inkGreen,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text("Voici votre exploitation en un coup d'œil."),
            const SizedBox(height: 24),
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
