import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/library_model.dart';
import '../services/theme_notifier.dart';
import '../widgets/book_card.dart';
import 'add_edit_book_screen.dart';
import 'book_detail_screen.dart';
import 'stats_screen.dart';

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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Tab _fittedTab(String label) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1),
      ),
    );
  }

  List<Book> _filter(List<Book> books) {
    if (_query.trim().isEmpty) return books;
    final q = _query.toLowerCase();
    return books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();

    if (library.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeNotifier = context.watch<ThemeNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Companion'),
        actions: [
          IconButton(
            icon: Icon(themeNotifier.icon),
            tooltip: themeNotifier.label,
            onPressed: () => context.read<ThemeNotifier>().cycle(),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export') {
                final path = await library.export();
                if (context.mounted && path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported to $path')),
                  );
                }
              } else if (value == 'import') {
                final imported = await context.read<LibraryModel>().importFromFile();
                if (context.mounted && imported) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Library imported')),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Export library')),
              PopupMenuItem(value: 'import', child: Text('Import library')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // Fixed (not scrollable) so all 4 tabs share the width evenly
          // instead of overflowing and cutting the last one off.
          isScrollable: false,
          tabs: [
            _fittedTab('Reading (${library.reading.length})'),
            _fittedTab('To Read (${library.toRead.length})'),
            _fittedTab('Read (${library.read.length})'),
            _fittedTab('Dropped (${library.dropped.length})'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title or author',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BookList(books: _filter(library.reading)),
                _BookList(books: _filter(library.toRead)),
                _BookList(books: _filter(library.read)),
                _BookList(books: _filter(library.dropped)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditBookScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final List<Book> books;
  const _BookList({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const Center(child: Text('No books here yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        return BookCard(
          book: book,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
          ),
        );
      },
    );
  }
}
