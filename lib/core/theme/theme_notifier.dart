import 'package:floafinwatch/core/storage/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  SecureStorageService get _storage => ref.read(secureStorageServiceProvider);

  @override
  ThemeMode build() {
    final initial = ref.watch(initialThemeModeProvider);
    _loadSavedTheme();
    // Default to system mode when app is freshly installed
    return initial;
  }

  Future<void> _loadSavedTheme() async {
    try {
      final raw = await _storage.getThemeMode();
      if (raw != null) {
        final mode = _parseThemeMode(raw);
        if (state != mode) {
          state = mode;
        }
      }
    } catch (_) {
      // Graceful fallback to default system
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final str = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _storage.saveThemeMode(str);
    } catch (_) {
      // Gracefully ignore storage write failures
    }
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  static ThemeMode _parseThemeMode(String raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  bool get isDarkMode => state == ThemeMode.dark;
}
