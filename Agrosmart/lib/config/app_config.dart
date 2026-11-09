import 'dart:convert';

import 'package:flutter/services.dart';

/// Where the local secrets live. The file is ignored by git; copy
/// `assets/config/env.example.json` to create it.
const envAssetPath = 'assets/config/env.json';

/// Runtime configuration (Google Gemini key and model).
///
/// Read at startup from [envAssetPath], so the key works however the app is
/// launched (F5, ▶, `flutter run`). A `--dart-define=GEMINI_API_KEY=…` still
/// takes priority when given.
///
/// Note: like any key shipped inside an app, it can be extracted from the
/// APK. Fine for development; in production call Gemini from a server.
class AppConfig {
  AppConfig._();

  static String geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY');
  static String geminiModel = const String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static Future<void> load([AssetBundle? bundle]) async {
    final Map<String, dynamic> env;
    try {
      env = jsonDecode(
        await (bundle ?? rootBundle).loadString(envAssetPath),
      ) as Map<String, dynamic>;
    } catch (_) {
      return; // No env.json: the AI screens explain the key is missing.
    }
    final key = env['GEMINI_API_KEY']?.toString().trim() ?? '';
    final model = env['GEMINI_MODEL']?.toString().trim() ?? '';
    if (geminiApiKey.isEmpty && key.isNotEmpty) geminiApiKey = key;
    if (!const bool.hasEnvironment('GEMINI_MODEL') && model.isNotEmpty) {
      geminiModel = model;
    }
  }
}
