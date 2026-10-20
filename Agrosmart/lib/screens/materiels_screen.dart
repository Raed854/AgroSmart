import 'package:flutter/material.dart';

import '../widgets/management_scaffold.dart';

class MaterielsScreen extends StatelessWidget {
  const MaterielsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ManagementScaffold(
        title: 'Matériels',
        subtitle: 'Track equipment availability and maintenance.',
        icon: Icons.handyman_outlined,
        items: [
          ManagementItem(
            title: 'AgroDrone X2',
            subtitle: 'Available  •  Battery 92%',
            icon: Icons.flight_takeoff_rounded,
          ),
          ManagementItem(
            title: 'John Deere 6M',
            subtitle: 'Maintenance due in 5 days',
            icon: Icons.agriculture_rounded,
          ),
        ],
      );
}
