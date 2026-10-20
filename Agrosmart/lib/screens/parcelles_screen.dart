import 'package:flutter/material.dart';

import '../widgets/management_scaffold.dart';

class ParcellesScreen extends StatelessWidget {
  const ParcellesScreen({super.key});

  @override
  Widget build(BuildContext context) => const ManagementScaffold(
        title: 'Parcelles',
        subtitle: 'Monitor every field from one simple view.',
        icon: Icons.landscape_outlined,
        items: [
          ManagementItem(
            title: 'North Field',
            subtitle: '12.4 ha  •  Wheat',
            icon: Icons.terrain_rounded,
          ),
          ManagementItem(
            title: 'River Plot',
            subtitle: '8.2 ha  •  Corn',
            icon: Icons.water_rounded,
          ),
        ],
      );
}
