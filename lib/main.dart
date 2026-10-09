import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:floafinwatch/core/storage/secure_storage_service.dart';
import 'package:floafinwatch/core/theme/theme_notifier.dart';
import 'package:floafinwatch/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[Firebase Init Error] $e');
  }

  try {
    await LiquidGlassShaders.ensureLoaded();
  } catch (_) {
    // Graceful fallback for environments without runtime shader compilation
  }
  await initializeDateFormatting('id_ID', null);

  ThemeMode initialThemeMode = ThemeMode.system;
  try {
    final storage = SecureStorageService();
    final savedThemeStr = await storage.getThemeMode();
    if (savedThemeStr != null) {
      initialThemeMode = switch (savedThemeStr) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.system,
      };
    }
  } catch (_) {
    // Default fallback is system
  }

  runApp(
    ProviderScope(
      overrides: [
        initialThemeModeProvider.overrideWithValue(initialThemeMode),
      ],
      child: const LoafinwatchApp(),
    ),
  );
}
