import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/library_model.dart';
import '../services/library_query.dart';
import '../theme/tokens.dart';
import '../widgets/book_row.dart';
import '../widgets/ledger.dart';
import '../widgets/set_page_dialog.dart';
import 'add_edit_book_screen.dart';
import 'backup_screen.dart';
import 'book_detail_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this)
    ..addListener(_refresh);
  final _search = TextEditingController();
  final _query = LibraryQuery();
  final _selected = <String>{};
  static const _statuses = [
    BookStatus.reading,
    BookStatus.toRead,
    BookStatus.read,
    BookStatus.onHold,
    BookStatus.dropped,
  ];
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _open(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));
  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });
  Future<void> _bulk(LibraryModel library, String action) async {
    final ids = Set<String>.of(_selected);
    bool ok;
    if (action == 'delete') {
      ok = await library.bulk(ids, deleted: true);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ids.length} books moved to trash.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                for (final id in ids) {
                  await library.restoreBook(id);
                }
              },
            ),
          ),
        );
      }
    } else if (action == 'tag') {
      final controller = TextEditingController();
      final tag = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tag selected books'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tag'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Apply tag'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (tag == null || tag.isEmpty) return;
      ok = await library.bulk(ids, tag: tag);
    } else {
      ok = await library.bulk(ids, status: BookStatus.values.byName(action));
    }
    if (ok && mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? 'Book Companion'
                          : '${_selected.length} selected',
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    IconButton(
                      tooltip: 'Cancel selection',
                      onPressed: () => setState(_selected.clear),
                      icon: const Icon(Icons.close),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Bulk actions',
                      onSelected: (v) => _bulk(library, v),
                      itemBuilder: (_) => [
                        ...BookStatus.values.map(
                          (s) => PopupMenuItem(
                            value: s.name,
                            child: Text('Move to ${s.label}'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'tag',
                          child: Text('Add tag'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Move to trash'),
                        ),
                      ],
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: 'Stats',
                      onPressed: () => _open(const StatsScreen()),
                      icon: const Icon(Icons.bar_chart),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => _open(const SettingsScreen()),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ],
              ),
            ),
            if (library.loading)
              const Expanded(child: LoadingRows())
            else if (library.loadFailed)
              Expanded(
                child: ErrorState(
                  headline: 'Your library could not be read',
                  body:
                      'Your saved file has been kept. Retry loading, or restore a backup after reviewing it.',
                  actionLabel: 'Try again',
                  onAction: library.load,
                  secondaryLabel: 'Restore backup',
                  onSecondary: () => _open(const BackupScreen()),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('library-search'),
                        controller: _search,
                        onChanged: (v) => setState(() => _query.search = v),
                        decoration: InputDecoration(
                          hintText: 'Search your library',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _query.search = '';
                                  }),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _query.hasFilters
                          ? 'Filters active'
                          : 'Sort and filter',
                      onPressed: () => _filters(library),
                      icon: Icon(
                        _query.hasFilters ? Icons.filter_alt : Icons.tune,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: LedgerTabs(
                  controller: _tabs,
                  labels: const [
                    'reading',
                    'to read',
                    'read',
                    'on hold',
                    'dropped',
                  ],
                  counts: _statuses
                      .map(
                        (s) => library.books.where((b) => b.status == s).length,
                      )
                      .toList(),
                ),
              ),
              if (_query.hasFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextButton(
                    onPressed: () => setState(() {
                      _query.tag = null;
                      _query.series = null;
                      _query.format = null;
                      _query.finishedYear = null;
                      _query.rating = null;
                    }),
                    child: const Text('Clear active filters'),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: _statuses.map((status) {
                    final books = _query.apply(
                      library.books.where((b) => b.status == status).toList(),
                    );
                    if (books.isEmpty) {
                      return EmptyState(
                        headline: _query.search.isNotEmpty || _query.hasFilters
                            ? 'No matching books on this shelf'
                            : status == BookStatus.reading
                            ? 'Nothing open right now'
                            : '${status.label} is empty',
                        body: _query.search.isNotEmpty || _query.hasFilters
                            ? 'Try another shelf, a shorter search, or clear filters. Search includes notes, tags, series and quotes.'
                            : library.books.isEmpty
                            ? 'Add your first book, or restore a .bcbackup, JSON or Goodreads CSV from Settings.'
                            : status == BookStatus.onHold
                            ? 'Pause a read without dropping it. Your page and history stay here until you resume.'
                            : 'Move books here from their detail screen, or choose a shelf when adding one.',
                        actionLabel: 'Add book',
                        onAction: () => _open(const AddEditBookScreen()),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: books.length,
                      separatorBuilder: (_, _) => const Divider(indent: 98),
                      itemBuilder: (context, index) {
                        final b = books[index];
                        return GestureDetector(
                          key: ValueKey('book-${b.id}'),
                          onLongPress: () => _toggle(b.id),
                          child: ColoredBox(
                            color: _selected.contains(b.id)
                                ? context.c.well
                                : Colors.transparent,
                            child: Row(
                              children: [
                                if (_selected.isNotEmpty)
                                  Checkbox(
                                    value: _selected.contains(b.id),
                                    onChanged: (_) => _toggle(b.id),
                                  ),
                                Expanded(
                                  child: BookRow(
                                    book: b,
                                    onTap: () => _selected.isEmpty
                                        ? _open(BookDetailScreen(bookId: b.id))
                                        : _toggle(b.id),
                                    onSetPage:
                                        status == BookStatus.reading &&
                                            b.openSession != null &&
                                            _selected.isEmpty
                                        ? () => showSetPageDialog(context, b)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton:
          library.loading || library.loadFailed || _selected.isNotEmpty
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('add-book'),
              elevation: 0,
              backgroundColor: context.c.panel,
              foregroundColor: context.c.ink,
              shape: RoundedRectangleBorder(
                borderRadius: Radii.field,
                side: BorderSide(color: context.c.ruleStrong),
              ),
              onPressed: () => _open(const AddEditBookScreen()),
              icon: const Icon(Icons.add),
              label: const Text('Add book'),
            ),
    );
  }

  Future<void> _filters(LibraryModel library) async {
    final tags = library.books.expand((b) => b.tags).toSet().toList()..sort();
    final series =
        library.books
            .map((b) => b.series)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final years =
        library.books
            .expand((b) => b.sessions)
            .where((s) => s.endDate != null && s.precision.name != 'unknown')
            .map((s) => s.endDate!.year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SectionHeading('sort & filter'),
                const SizedBox(height: 12),
                DropdownButtonFormField<LibrarySort>(
                  isExpanded: true,
                  initialValue: _query.sort,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  items: LibrarySort.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                      )
                      .toList(),
                  onChanged: (s) => update(() => _query.sort = s!),
                ),
                SwitchListTile(
                  title: const Text('Descending order'),
                  value: _query.descending,
                  onChanged: (v) => update(() => _query.descending = v),
                ),
                _filterDrop<String>(
                  'Tag / genre',
                  _query.tag,
                  tags,
                  (s) => s,
                  (s) => update(() => _query.tag = s),
                ),
                _filterDrop<BookFormat>(
                  'Format',
                  _query.format,
                  BookFormat.values,
                  (f) => f.label,
                  (f) => update(() => _query.format = f),
                ),
                _filterDrop<int>(
                  'Year finished',
                  _query.finishedYear,
                  years,
                  (y) => '$y',
                  (y) => update(() => _query.finishedYear = y),
                ),
                _filterDrop<int>(
                  'Rating (rounded average)',
                  _query.rating,
                  [1, 2, 3, 4, 5],
                  (r) => '$r stars',
                  (r) => update(() => _query.rating = r),
                ),
                _filterDrop<String>(
                  'Series',
                  _query.series,
                  series,
                  (s) => s,
                  (s) => update(() => _query.series = s),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _filterDrop<T>(
    String label,
    T? value,
    List<T> values,
    String Function(T) name,
    ValueChanged<T?> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(value: null, child: const Text('All')),
        ...values.map((v) => DropdownMenuItem(value: v, child: Text(name(v)))),
      ],
      onChanged: change,
    ),
  );
}
