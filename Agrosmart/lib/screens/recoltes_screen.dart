import 'package:flutter/material.dart';

import '../main.dart';

class RecoltesScreen extends StatelessWidget {
  const RecoltesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text('Récoltes', style: TextStyle(color: inkGreen)),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.agriculture_rounded,
                size: 80,
                color: mutedGreen.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Récoltes',
                style: TextStyle(
                  color: inkGreen,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cette fonctionnalité sera bientôt disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedGreen,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enregistrez vos récoltes et protégez votre rendement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedGreen.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
