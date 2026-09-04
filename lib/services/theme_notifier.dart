import 'package:flutter/material.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;

  void cycle() {
    mode = switch (mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    notifyListeners();
  }

  String get label => switch (mode) {
        ThemeMode.system => 'Theme: System',
        ThemeMode.light => 'Theme: Light',
        ThemeMode.dark => 'Theme: Dark',
      };

  // Outlined glyphs: the brightness_auto starburst read as a logo
  // sitting next to the app title.
  IconData get icon => switch (mode) {
        ThemeMode.system => Icons.settings_brightness_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };
}
