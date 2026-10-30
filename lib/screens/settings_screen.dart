import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reading_session.dart';
import '../services/library_model.dart';
import '../services/theme_notifier.dart';
import '../widgets/ledger.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<ThemeNotifier>();
    final library = context.watch<LibraryModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeading('appearance'),
          const SizedBox(height: 12),
          DropdownButtonFormField<ThemeMode>(
            isExpanded: true,
            initialValue: prefs.mode,
            decoration: const InputDecoration(labelText: 'Theme'),
            items: ThemeMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (m) => prefs.update({'theme': m!.name}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Material You colors'),
            subtitle: const Text(
              'Use your wallpaper palette where Android supports it.',
            ),
            value: prefs.dynamicColor,
            onChanged: (v) => prefs.update({'dynamicColor': v}),
          ),
          const SizedBox(height: 20),
          const SectionHeading('privacy'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide recent-apps preview'),
            subtitle: const Text(
              'Also blocks screenshots and screen recording.',
            ),
            value: prefs.securePreview,
            onChanged: (v) => prefs.update({'securePreview': v}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('App lock'),
            subtitle: const Text(
              'Use your device PIN or biometrics on launch and after leaving the app. Widget hides book details.',
            ),
            value: prefs.appLock,
            onChanged: (v) async {
              final ok = await prefs.authenticate();
              if (!context.mounted) return;
              if (ok) {
                await prefs.update({'appLock': v});
                await library.refreshWidget(private: v);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Authentication was not completed. Configure a device lock in Android settings if needed.',
                    ),
                  ),
                );
              }
            },
          ),
          const Text(
            'No accounts, telemetry or network access. Android cloud backup is disabled. App lock controls access to the app; exported files remain under your control.',
          ),
          const SizedBox(height: 24),
          const SectionHeading('reading preferences'),
          const SizedBox(height: 12),
          DropdownButtonFormField<DatePrecision>(
            isExpanded: true,
            initialValue: prefs.defaultPrecision,
            decoration: const InputDecoration(
              labelText: 'Default date precision',
            ),
            items: DatePrecision.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                .toList(),
            onChanged: (p) => prefs.update({'defaultPrecision': p!.name}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: prefs.firstDayOfWeek,
            decoration: const InputDecoration(labelText: 'First day of week'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Monday')),
              DropdownMenuItem(value: 0, child: Text('Sunday')),
            ],
            onChanged: (v) => prefs.update({'firstDayOfWeek': v}),
          ),
          const SizedBox(height: 24),
          const SectionHeading('your data'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Backups, import & export'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily automatic snapshots'),
            subtitle: const Text('Imports always take a snapshot.'),
            value: prefs.autoSnapshots,
            onChanged: (v) => prefs.update({'autoSnapshots': v}),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Trash (${library.trash.length})'),
            subtitle: const Text('Restore deleted books for 30 days.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const TrashScreen()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Export diagnostics'),
            subtitle: const Text(
              'Local error types and counts. No titles, notes or photos.',
            ),
            onTap: () async {
              try {
                final log = await library.storage.file('diagnostics.log');
                final contents =
                    '${library.diagnosticSummary}\n${await log.exists() ? await log.readAsString() : 'No local errors recorded.'}';
                await library.storage.saveExport(
                  'book_companion_diagnostics.txt',
                  utf8.encode(contents),
                );
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not export diagnostics. Please try again.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
          if (prefs.error != null) Text(prefs.error!),
          const SizedBox(height: 24),
          const Text(
            'Home-screen widget: long-press your Android home screen, choose Widgets, then Book Companion. Tap its progress bar to update your current book.',
          ),
          OutlinedButton(
            onPressed: () async {
              try {
                final supported = await LibraryModel.platform
                    .invokeMethod<bool>('pinWidget');
                if (supported != true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Add the widget from your launcher’s Widgets menu.',
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Add the widget from your launcher’s Widgets menu.',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Add home-screen widget'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Trash')),
      body: library.trash.isEmpty
          ? const EmptyState(
              headline: 'Trash is empty',
              body:
                  'Deleted books can be restored here for 30 days. Their sessions, notes and covers stay together.',
            )
          : ListView(
              children: library.trash
                  .map(
                    (b) => ListTile(
                      title: Text(b.title),
                      subtitle: Text(
                        'Deleted ${b.deletedAt!.toLocal().toString().substring(0, 10)} · kept for 30 days',
                      ),
                      trailing: TextButton(
                        onPressed: () => library.restoreBook(b.id),
                        child: const Text('Restore'),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
