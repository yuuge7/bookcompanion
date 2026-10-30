import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../models/reading_session.dart';
import 'storage_service.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({StorageService? storage})
    : storage = storage ?? StorageService();
  final StorageService storage;
  ThemeMode mode = ThemeMode.system;
  bool loaded = false,
      securePreview = false,
      appLock = false,
      dynamicColor = false,
      autoSnapshots = true;
  DatePrecision defaultPrecision = DatePrecision.exact;
  int firstDayOfWeek = 1, goalYear = DateTime.now().year, goalTarget = 12;
  String goalUnit = 'books';
  String? error;
  Future<void> _queue = Future.value();
  Future<void> load() async {
    try {
      try {
        final nativeLock = await const MethodChannel(
          'book_companion/device',
        ).invokeMethod<bool>('appLockEnabled');
        if (nativeLock != null) appLock = nativeLock;
      } on MissingPluginException {
        /* Tests / other hosts. */
      }
      final p = await storage.loadSettings();
      mode = ThemeMode.values.byName(p['theme'] as String? ?? 'system');
      securePreview = p['securePreview'] == true;
      appLock = p['appLock'] == true;
      dynamicColor = p['dynamicColor'] == true;
      autoSnapshots = p['autoSnapshots'] != false;
      defaultPrecision = DatePrecision.values.byName(
        p['defaultPrecision'] as String? ?? 'exact',
      );
      firstDayOfWeek = p['firstDayOfWeek'] == 0 ? 0 : 1;
      goalYear = p['goalYear'] as int? ?? DateTime.now().year;
      goalTarget = p['goalTarget'] as int? ?? 12;
      goalUnit = p['goalUnit'] as String? ?? 'books';
      await applyPrivacy();
    } catch (e) {
      error =
          'Settings could not be loaded. Your saved settings have been kept.';
      await storage.logError('settings_load', e);
    }
    loaded = true;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'theme': mode.name,
    'securePreview': securePreview,
    'appLock': appLock,
    'dynamicColor': dynamicColor,
    'autoSnapshots': autoSnapshots,
    'defaultPrecision': defaultPrecision.name,
    'firstDayOfWeek': firstDayOfWeek,
    'goalYear': goalYear,
    'goalTarget': goalTarget,
    'goalUnit': goalUnit,
  };
  Future<bool> update(Map<String, dynamic> patch) async {
    var ok = false;
    await (_queue = _queue.then((_) async {
      try {
        final next = {...toJson(), ...patch};
        await storage.saveSettings(next);
        await load();
        error = null;
        ok = true;
      } catch (e) {
        error = 'Settings were not saved. Please try again.';
        await storage.logError('settings_save', e);
      }
      notifyListeners();
    }));
    return ok;
  }

  Future<void> applyPrivacy() async {
    try {
      await const MethodChannel(
        'book_companion/device',
      ).invokeMethod<void>('securePreview', securePreview || appLock);
      await const MethodChannel(
        'book_companion/device',
      ).invokeMethod<void>('widgetPrivacy', appLock);
    } on MissingPluginException {
      /* Tests / other hosts. */
    }
  }

  Future<bool> authenticate() async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: 'Unlock your book library',
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> cycle() => update({
    'theme': switch (mode) {
      ThemeMode.system => 'light',
      ThemeMode.light => 'dark',
      ThemeMode.dark => 'system',
    },
  });
  String get label => 'Theme: ${mode.name}';
  IconData get icon => switch (mode) {
    ThemeMode.system => Icons.settings_brightness_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };
}
