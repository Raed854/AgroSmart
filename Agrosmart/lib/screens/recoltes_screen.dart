import 'package:flutter/material.dart';

import '../widgets/management_scaffold.dart';

class RecoltesScreen extends StatelessWidget {
  const RecoltesScreen({super.key});

  @override
  Widget build(BuildContext context) => const ManagementScaffold(
        title: 'Récoltes',
        subtitle: 'Plan harvest windows and protect your yield.',
        icon: Icons.agriculture_rounded,
        items: [
          ManagementItem(
            title: 'Wheat harvest',
            subtitle: 'Expected in 12 days',
            icon: Icons.event_available_rounded,
          ),
          ManagementItem(
            title: 'Corn harvest',
            subtitle: 'Expected in 28 days',
            icon: Icons.calendar_month_rounded,
          ),
        ],
      );
}
