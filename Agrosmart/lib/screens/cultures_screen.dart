import 'package:flutter/material.dart';

import '../widgets/management_scaffold.dart';

class CulturesScreen extends StatelessWidget {
  const CulturesScreen({super.key});

  @override
  Widget build(BuildContext context) => const ManagementScaffold(
        title: 'Cultures',
        subtitle: 'Keep your crop cycles healthy and on schedule.',
        icon: Icons.grass_rounded,
        items: [
          ManagementItem(
            title: 'Wheat',
            subtitle: 'Growing  •  68% maturity',
            icon: Icons.grass_rounded,
          ),
          ManagementItem(
            title: 'Corn',
            subtitle: 'Growing  •  42% maturity',
            icon: Icons.eco_rounded,
          ),
        ],
      );
}
