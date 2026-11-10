import 'package:flutter/material.dart';

import '../main.dart';
import '../services/stock_service.dart';
import '../services/auth_service.dart';
import 'agriculteurs_screen.dart';
import 'drone_ai_screen.dart';
import 'drone_form_screen.dart';
import 'equipment_analytics_screen.dart';
import 'irrigation_planning_screen.dart';
import 'irrigation_screen.dart';
import 'maintenance_screen.dart';
import 'materiels_screen.dart';
import 'parcel_health_map_screen.dart';
import 'parcelles/parcelles_list_screen.dart';
import 'profile_screen.dart';
import 'stock_assistant_screen.dart';
import 'stocks_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _stockAlertCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAlertCount();
  }

  Future<void> _loadAlertCount() async {
    try {
      final count = await StockService.instance.getAlertCount();
      if (mounted) setState(() => _stockAlertCount = count);
    } catch (_) {
      // Si la base n'est pas encore initialisée, on ignore silencieusement
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final actions = [
      const _DashboardAction(
        'Agriculteurs',
        'Gérer les profils des agriculteurs',
        Icons.groups_rounded,
        AgriculteursScreen(),
        0,
      ),
      const _DashboardAction(
        'Parcelles',
        'Gérer vos parcelles et l’assistant IA',
        Icons.landscape_outlined,
        ParcellesListScreen(),
        0,
      ),
      _DashboardAction(
        'Stocks',
        _stockAlertCount > 0
            ? '$_stockAlertCount alerte(s) active(s)'
            : 'Inventaire à jour',
        Icons.inventory_2_outlined,
        const StocksScreen(),
        _stockAlertCount,
      ),
      const _DashboardAction(
        'Assistant stock',
        'Poser une question sur l’inventaire',
        Icons.forum_outlined,
        StockAssistantScreen(),
        0,
      ),
      const _DashboardAction(
        'Parcel Health Map',
        'AI anomaly detection',
        Icons.map_outlined,
        const ParcelHealthMapScreen(),
        0,
      ),
      _DashboardAction(
        'Irrigation',
        'Suivre les irrigations de vos parcelles',
        Icons.water_drop_outlined,
        const IrrigationScreen(),
        0,
      ),
      _DashboardAction(
        'Planning irrigation IA',
        "Planning adapté à la météo et à l'humidité",
        Icons.calendar_month_outlined,
        const IrrigationPlanningScreen(),
        0,
      ),
      _DashboardAction(
        'Drone',
        'Créer et gérer vos drones',
        Icons.flight_rounded,
        const DroneFormScreen(),
        0,
      ),
      _DashboardAction(
        'Drone AI',
        'Images du drone et diagnostic AI',
        Icons.biotech_outlined,
        const DroneAiScreen(),
        0,
      ),
      _DashboardAction(
        'Matériels',
        'Suivre vos équipements',
        Icons.handyman_outlined,
        const MaterielsScreen(),
        0,
      ),
      _DashboardAction(
        'Maintenance',
        "Carburant, maintenance et main d'œuvre",
        Icons.build_circle_outlined,
        const MaintenanceScreen(),
        0,
      ),
      _DashboardAction(
        'Statistiques & IA',
        'Carburant, maintenances prévues et durée de vie',
        Icons.insights_outlined,
        const EquipmentAnalyticsScreen(),
        0,
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
              style: const TextStyle(
                color: inkGreen,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text("Voici votre exploitation en un coup d'œil."),
            const SizedBox(height: 24),
            const Text(
              'Modules',
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (action.alertCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${action.alertCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => action.screen),
                    );
                    // Rafraîchit le badge après retour des Stocks
                    _loadAlertCount();
                  },
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
  const _DashboardAction(
    this.title,
    this.subtitle,
    this.icon,
    this.screen,
    this.alertCount,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
  final int alertCount;
}
