import 'package:flutter/material.dart';

import '../widgets/management_scaffold.dart';

class IrrigationScreen extends StatelessWidget {
  const IrrigationScreen({super.key});

  @override
  Widget build(BuildContext context) => const ManagementScaffold(
        title: 'Irrigation',
        subtitle: 'Use smart recommendations to save water.',
        icon: Icons.water_drop_outlined,
        items: [
          ManagementItem(
            title: 'North Field system',
            subtitle: 'Ready  •  Next cycle 06:30',
            icon: Icons.settings_input_antenna_rounded,
          ),
          ManagementItem(
            title: 'River Plot system',
            subtitle: 'Paused  •  Soil moisture 74%',
            icon: Icons.water_drop_rounded,
          ),
        ],
      );
}
