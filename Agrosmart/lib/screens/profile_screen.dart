import 'package:flutter/material.dart';

import '../main.dart';
import '../widgets/brand_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: pageBackground,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: inkGreen)),
        iconTheme: const IconThemeData(color: inkGreen),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          const BrandHeader(compact: true),
          const SizedBox(height: 32),
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFD5E8D0),
            child: Icon(Icons.person_rounded, color: forestGreen, size: 44),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Alex Morgan',
              style: TextStyle(
                color: inkGreen,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Center(child: Text('alex@greensmart.farm')),
          const SizedBox(height: 28),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: borderGreen),
            ),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.business_outlined, color: forestGreen),
                  title: Text('Farm'),
                  subtitle: Text('Green Valley Farm'),
                ),
                Divider(height: 1, color: borderGreen),
                ListTile(
                  leading: Icon(Icons.language_rounded, color: forestGreen),
                  title: Text('Language'),
                  subtitle: Text('English'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
