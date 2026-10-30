import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/export_service.dart';
import '../services/library_model.dart';
import '../services/storage_service.dart';
import '../widgets/ledger.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _message;
  List<File> _snapshots = [];
  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final files = await context.read<LibraryModel>().storage.snapshots();
    if (mounted) setState(() => _snapshots = files);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = e is LibraryFormatException
              ? e.message
              : 'The file operation failed. Your library has been kept.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _reload();
      }
    }
  }

  Future<void> _import([File? snapshot]) async {
    final library = context.read<LibraryModel>();
    final data = snapshot == null
        ? await library.storage.pickImport()
        : library.storage.decodeBackup(await snapshot.readAsBytes());
    if (data == null || !mounted) return;
    setState(() => _busy = false);
    var mode = ImportMode.merge;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final preview = library.preview(data, mode);
          return AlertDialog(
            title: const Text('Review import'),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.books.length} books in this file. ${library.allBooks.length} currently saved (including trash).',
                ),
                const SizedBox(height: 16),
                SegmentedChoice<ImportMode>(
                  values: ImportMode.values,
                  value: mode,
                  labelOf: (m) => m.name,
                  onChanged: (m) => update(() => mode = m),
                ),
                const SizedBox(height: 16),
                Text(
                  '+${preview.added} new · ${preview.changed} changed · ${preview.removed} removed · ${preview.unchanged} kept',
                ),
                const SizedBox(height: 12),
                Text(
                  mode == ImportMode.replace
                      ? 'Replace your ${library.allBooks.length} books with ${data.books.length} from this file?'
                      : 'Matching IDs use the newer updated date. Ties keep your current copy, including deleted books.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'An automatic snapshot is saved before any changes. JSON and CSV do not contain cover images; use .bcbackup for a complete move.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  mode == ImportMode.replace
                      ? 'Replace library'
                      : 'Merge library',
                ),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;
    if (mounted) setState(() => _busy = true);
    final ok = await library.importData(data, mode);
    if (mounted) {
      setState(
        () => _message = ok
            ? 'Import complete. A recovery snapshot is available below.'
            : library.saveError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Backups & files')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeading('keep your library safe'),
          const SizedBox(height: 12),
          const Text(
            'A .bcbackup file includes every book, reading session, quote, cover and trash entry. Save a copy somewhere you control.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || library.loadFailed
                ? null
                : () => _run(() async {
                    final path = await library.export();
                    if (path != null && mounted) {
                      setState(() => _message = 'Complete backup exported.');
                    }
                  }),
            child: const Text('Export complete backup'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _run(_import),
            child: const Text('Import / restore file'),
          ),
          const SizedBox(height: 24),
          const SectionHeading('other exports'),
          const Text(
            'JSON is compatible with earlier exports. CSV opens in spreadsheets. HTML and PDF are ready to print. Covers travel in complete backups.',
          ),
          Wrap(
            spacing: 8,
            children: ['json', 'csv', 'html', 'pdf']
                .map(
                  (format) => OutlinedButton(
                    onPressed: _busy || library.loadFailed
                        ? null
                        : () => _run(() async {
                            final path = await ExportService(
                              library.storage,
                            ).export(library.books, format);
                            if (path != null && mounted) {
                              setState(
                                () => _message =
                                    '${format.toUpperCase()} exported.',
                              );
                            }
                          }),
                    child: Text(format.toUpperCase()),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          const SectionHeading('automatic snapshots'),
          const Text(
            'The 10 newest snapshots stay on this device. Restore opens the same import preview. Copy one out before moving phones.',
          ),
          if (_snapshots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No snapshots yet. One is created before an import and before the first library change each day.',
              ),
            ),
          ..._snapshots.map(
            (file) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                file.lastModifiedSync().toLocal().toString().split('.').first,
              ),
              subtitle: Text(
                '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB · complete backup',
              ),
              trailing: PopupMenuButton<String>(
                enabled: !_busy,
                onSelected: (action) => _run(() async {
                  if (action == 'restore') {
                    await _import(file);
                  } else {
                    await library.storage.saveExport(
                      'snapshot.bcbackup',
                      await file.readAsBytes(),
                    );
                  }
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'restore',
                    child: Text('Restore preview'),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text('Export snapshot'),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SelectableText(_message!),
            ),
        ],
      ),
    );
  }
}
