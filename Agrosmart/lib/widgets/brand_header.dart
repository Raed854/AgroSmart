import 'package:flutter/material.dart';

import '../main.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 44 : 48,
          height: compact ? 44 : 48,
          decoration: BoxDecoration(
            color: forestGreen,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: forestGreen.withValues(alpha: .18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.eco_rounded, color: Colors.white, size: 27),
              Positioned(
                right: 7,
                top: 7,
                child: Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFB7E7B8),
                  size: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AgroSmart AI',
              style: TextStyle(
                color: forestGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Smart Farming, Better Future 🌱',
              style: TextStyle(
                color: mutedGreen,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
