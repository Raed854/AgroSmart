import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/brand_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

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
          Center(
            child: Text(
              user?.name ?? 'Non connecté',
              style: const TextStyle(
                color: inkGreen,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (user != null) Center(child: Text(user.email)),
          const SizedBox(height: 28),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: borderGreen),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.business_outlined,
                    color: forestGreen,
                  ),
                  title: const Text('Farm'),
                  subtitle: Text(user?.farmName ?? 'Non renseignée'),
                ),
                const Divider(height: 1, color: borderGreen),
                const ListTile(
                  leading: Icon(Icons.language_rounded, color: forestGreen),
                  title: Text('Language'),
                  subtitle: Text('English'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: borderGreen),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFD66555)),
              title: const Text(
                'Sign out',
                style: TextStyle(
                  color: Color(0xFFD66555),
                  fontWeight: FontWeight.w800,
                ),
              ),
              onTap: () => _signOut(context),
            ),
          ),
        ],
      ),
    );
  }
}
