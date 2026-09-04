import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/library_model.dart';
import '../services/theme_notifier.dart';
import '../theme/tokens.dart';
import '../widgets/book_row.dart';
import '../widgets/ledger.dart';
import '../widgets/set_page_dialog.dart';
import 'add_edit_book_screen.dart';
import 'book_detail_screen.dart';
import 'stats_screen.dart';

/// The log itself, and the surface this app lives on.
///
/// Everything above the list is chrome, so it is kept to three bands —
/// masthead, search, tabs — and the tab counts do the work a separate
/// summary row used to. Below them the list is one ruled page rather than
/// a stack of floating cards.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Book> _filter(List<Book> books) {
    if (_query.trim().isEmpty) return books;
    final q = _query.trim().toLowerCase();
    return books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
        .toList();
  }

  void _openBook(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
    );
  }

  Future<void> _addBook() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEditBookScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final c = context.c;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Masthead(),
            if (library.loadFailed)
              Expanded(
                child: ErrorState(
                  headline: 'Your library file could not be read',
                  body: 'The saved file is there but is not in a format this '
                      'app understands, so nothing has been loaded — and '
                      'nothing will be overwritten. Try loading it again, or '
                      'replace it with a library you exported.',
                  actionLabel: 'Try again',
                  onAction: () => context.read<LibraryModel>().load(),
                  secondaryLabel: 'Import library',
                  onSecondary: () => _importLibrary(context),
                ),
              )
            else if (library.loading)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: Space.gutter),
                  child: LoadingRows(),
                ),
              )
            else ...[
              _SearchField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
              const SizedBox(height: Space.step),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.step),
                child: LedgerTabs(
                  controller: _tabController,
                  labels: const ['reading', 'to read', 'read', 'dropped'],
                  counts: [
                    library.reading.length,
                    library.toRead.length,
                    library.read.length,
                    library.dropped.length,
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _LedgerPage(
                      books: _filter(library.reading),
                      empty: _emptyFor(BookStatus.reading),
                      onOpen: _openBook,
                      allowSetPage: true,
                    ),
                    _LedgerPage(
                      books: _filter(library.toRead),
                      empty: _emptyFor(BookStatus.toRead),
                      onOpen: _openBook,
                    ),
                    _LedgerPage(
                      books: _filter(library.read),
                      empty: _emptyFor(BookStatus.read),
                      onOpen: _openBook,
                    ),
                    _LedgerPage(
                      books: _filter(library.dropped),
                      empty: _emptyFor(BookStatus.dropped),
                      onOpen: _openBook,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: library.loading || library.loadFailed
          ? null
          : _AddButton(onPressed: _addBook, color: c),
    );
  }

  Future<void> _importLibrary(BuildContext context) async {
    final library = context.read<LibraryModel>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await library.importFromFile();
    reportImport(messenger, result);
  }

  /// Empty copy names what belongs in this tab and the move that fills it,
  /// so a blank tab is never just "nothing here".
  Widget _emptyFor(BookStatus status) {
    if (_query.trim().isNotEmpty) {
      return EmptyState(
        headline: 'No match for "${_query.trim()}"',
        body: 'Nothing in this tab has that in its title or author. Search '
            'covers every tab separately, so try another one.',
        actionLabel: 'Clear search',
        onAction: () {
          _searchController.clear();
          setState(() => _query = '');
        },
      );
    }

    return switch (status) {
      BookStatus.reading => EmptyState(
          headline: 'Nothing open right now',
          body: 'Books you have started show up here with their page count, '
              'so you can log where you got to in one tap.',
          actionLabel: 'Add book',
          onAction: _addBook,
        ),
      BookStatus.toRead => EmptyState(
          headline: 'Your shelf is empty',
          body: 'Add the books you mean to get to. You can start a read from '
              'a book later without adding it again.',
          actionLabel: 'Add book',
          onAction: _addBook,
        ),
      BookStatus.read => const EmptyState(
          headline: 'No finished reads yet',
          body: 'Finishing a book closes its session with an end date and an '
              'optional rating, and it lands here. Rereads add a new session '
              'rather than replacing the first one.',
        ),
      BookStatus.dropped => const EmptyState(
          headline: 'Nothing dropped',
          body: 'A book you set aside keeps its open session, so the page you '
              'stopped on stays on record.',
        ),
    };
  }
}

/// Flat header on the ground colour: no elevation, no tint, no back
/// shadow, and square icon buttons instead of 40px circles.
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final themeNotifier = context.watch<ThemeNotifier>();
    final library = context.read<LibraryModel>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.step,
        Space.snug,
        Space.step,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Book Companion',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          _SquareAction(
            icon: themeNotifier.icon,
            tooltip: themeNotifier.label,
            onPressed: () => context.read<ThemeNotifier>().cycle(),
          ),
          _SquareAction(
            icon: Icons.bar_chart,
            tooltip: 'Stats',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Library file',
            icon: Icon(Icons.more_horiz, color: c.ink),
            position: PopupMenuPosition.under,
            onSelected: (value) => _runFileAction(context, library, value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Export library')),
              PopupMenuItem(value: 'import', child: Text('Import library')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runFileAction(
    BuildContext context,
    LibraryModel library,
    String value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    if (value == 'export') {
      final path = await library.export();
      if (path != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Library exported.')));
      }
      return;
    }

    reportImport(messenger, await library.importFromFile());
  }
}

/// Says what the import did, in the same words wherever it is started
/// from — the menu, or the unreadable-file screen.
void reportImport(ScaffoldMessengerState messenger, ImportResult result) {
  final message = switch (result) {
    ImportResult.replaced => 'Library imported.',
    ImportResult.unreadable =>
      'That file is not a Book Companion export. Pick a JSON file exported '
          'from this app.',
    ImportResult.cancelled => null,
  };
  if (message == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      color: context.c.ink,
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontFamily: Faces.body,
          fontSize: 14,
          color: c.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Search title or author',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.step,
            vertical: 10,
          ),
          prefixIcon: Icon(Icons.search, size: 17, color: c.inkFaint),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 38,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  color: c.inkMuted,
                ),
          border: const OutlineInputBorder(
            borderRadius: Radii.field,
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: Radii.field,
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Entries printed straight onto the page. There is no card between a row
/// and the paper, and no container to sit half-empty when a tab is short —
/// the log simply stops where the entries stop.
class _LedgerPage extends StatelessWidget {
  const _LedgerPage({
    required this.books,
    required this.empty,
    required this.onOpen,
    this.allowSetPage = false,
  });

  final List<Book> books;
  final Widget empty;
  final ValueChanged<Book> onOpen;
  final bool allowSetPage;

  /// Left edge of the title column: gutter + spine + gap + cover + gap.
  static const _textInset = 98.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (books.isEmpty) return empty;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: books.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(left: _textInset),
        child: Container(height: 1, color: c.rule),
      ),
      itemBuilder: (context, i) {
        final book = books[i];
        return BookRow(
          book: book,
          onTap: () => onOpen(book),
          onSetPage: allowSetPage && book.openSession != null
              ? () => showSetPageDialog(context, book)
              : null,
        );
      },
    );
  }
}

/// Deliberately quiet. Adding a book is occasional; the loudest thing on
/// this screen should be a half-full spine, not a button.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed, required this.color});

  final VoidCallback onPressed;
  final LedgerColors color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add book',
      excludeSemantics: true,
      child: Material(
        color: color.panel,
        borderRadius: Radii.field,
        child: InkWell(
          onTap: onPressed,
          borderRadius: Radii.field,
          child: Container(
            height: kTapTarget,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            decoration: BoxDecoration(
              borderRadius: Radii.field,
              border: Border.all(color: color.ruleStrong, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 18, color: color.ink),
                const SizedBox(width: Space.snug),
                Meta('add book', color: color.ink, weight: FontWeight.w600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
