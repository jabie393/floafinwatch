import 'package:floafinwatch/core/theme/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeModeNotifier Tests', () {
    test('defaults to ThemeMode.system when freshly installed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = container.read(themeModeProvider);
      expect(mode, equals(ThemeMode.system));
    });

    test('boots with overridden initial theme when loaded from storage', () {
      final container = ProviderContainer(
        overrides: [
          initialThemeModeProvider.overrideWithValue(ThemeMode.light),
        ],
      );
      addTearDown(container.dispose);

      final mode = container.read(themeModeProvider);
      expect(mode, equals(ThemeMode.light));
    });

    test('can change theme mode to dark, light, and system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeModeProvider.notifier);

      notifier.setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), equals(ThemeMode.dark));
      expect(notifier.isDarkMode, isTrue);

      notifier.setThemeMode(ThemeMode.light);
      expect(container.read(themeModeProvider), equals(ThemeMode.light));
      expect(notifier.isDarkMode, isFalse);

      notifier.setThemeMode(ThemeMode.system);
      expect(container.read(themeModeProvider), equals(ThemeMode.system));
    });

    test('toggleTheme alternates between dark and light', () {
      final container = ProviderContainer(
        overrides: [
          initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(themeModeProvider.notifier);
      expect(container.read(themeModeProvider), equals(ThemeMode.dark));

      notifier.toggleTheme();
      expect(container.read(themeModeProvider), equals(ThemeMode.light));

      notifier.toggleTheme();
      expect(container.read(themeModeProvider), equals(ThemeMode.dark));
    });
  });
}
