import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LiquidGlassShaders.ensureLoaded();
  } catch (_) {
    // Graceful fallback for environments without runtime shader compilation
  }
  await initializeDateFormatting('id_ID', null);
  runApp(
    const ProviderScope(
      child: LoafinwatchApp(),
    ),
  );
}
