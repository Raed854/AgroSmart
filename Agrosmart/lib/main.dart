import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

const forestGreen = Color(0xFF1B5E20);
const freshGreen = Color(0xFF4CAF50);
const inkGreen = Color(0xFF16351B);
const mutedGreen = Color(0xFF6E7F72);
const pageBackground = Color(0xFFF8F7F1);
const borderGreen = Color(0xFFE4E9E1);

void main() {
  runApp(const AgroSmartApp());
}

class AgroSmartApp extends StatelessWidget {
  const AgroSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroSmart AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: freshGreen,
          brightness: Brightness.light,
        ).copyWith(
          primary: forestGreen,
          onPrimary: Colors.white,
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: inkGreen,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
          titleLarge: TextStyle(
            color: inkGreen,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          bodyMedium: TextStyle(
            color: mutedGreen,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
    );
  }
}
