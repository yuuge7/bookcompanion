import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import '../services/library_query.dart';
import 'ledger.dart';

class LibraryFilters extends StatefulWidget {
  const LibraryFilters({
    super.key,
    required this.query,
    required this.books,
    required this.shelf,
  });
  final LibraryQuery query;
  final List<Book> books;
  final BookStatus shelf;
  @override
  State<LibraryFilters> createState() => _LibraryFiltersState();
}

class _LibraryFiltersState extends State<LibraryFilters> {
  late final LibraryQuery _draft = widget.query.copy();

  Widget _filter<T>(
    String label,
    T? value,
    List<T> values,
    String Function(T) name,
    ValueChanged<T?> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      key: ValueKey('$label-$value'),
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(value: null, child: const Text('All')),
        ...values.map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(name(v), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) => setState(() => change(v)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tags = widget.books.expand((b) => b.tags).toSet().toList()..sort();
    final series =
        widget.books
            .map((b) => b.series)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final years =
        widget.books
            .expand((b) => b.sessions)
            .where((s) => !s.isOpen && s.precision != DatePrecision.unknown)
            .map((s) => s.endDate!.year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final count = _draft
        .apply(widget.books.where((b) => b.status == widget.shelf).toList())
        .length;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sort and filter',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel filters',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                children: [
                  const SectionHeading('sort books'),
                  const SizedBox(height: 8),
                  Text(
                    'Applies to all shelves. Preview: ${widget.shelf.label}.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<LibrarySort>(
                    key: ValueKey('sort-${_draft.sort.name}'),
                    isExpanded: true,
                    initialValue: _draft.sort,
                    decoration: const InputDecoration(labelText: 'Sort by'),
                    items: LibrarySort.values
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.label)),
                        )
                        .toList(),
                    onChanged: (s) => setState(() {
                      _draft.sort = s!;
                      _draft.descending = s.defaultDescending;
                    }),
                  ),
                  const SizedBox(height: 12),
                  SegmentedChoice<bool>(
                    values: const [false, true],
                    value: _draft.descending,
                    labelOf: (v) => v
                        ? _draft.sort.descendingLabel
                        : _draft.sort.ascendingLabel,
                    onChanged: (v) => setState(() => _draft.descending = v),
                  ),
                  const SizedBox(height: 28),
                  const SectionHeading('filter books'),
                  const SizedBox(height: 16),
                  _filter<String>(
                    'Tag / genre',
                    _draft.tag,
                    tags,
                    (s) => s,
                    (s) => _draft.tag = s,
                  ),
                  _filter<BookFormat>(
                    'Format of any read',
                    _draft.format,
                    BookFormat.values,
                    (f) => f.label,
                    (f) => _draft.format = f,
                  ),
                  _filter<int>(
                    'Year finished',
                    _draft.finishedYear,
                    years,
                    (y) => '$y',
                    (y) => _draft.finishedYear = y,
                  ),
                  _filter<int>(
                    'Rating (rounded average)',
                    _draft.rating,
                    [1, 2, 3, 4, 5],
                    (r) => '$r stars',
                    (r) => _draft.rating = r,
                  ),
                  _filter<String>(
                    'Series',
                    _draft.series,
                    series,
                    (s) => s,
                    (s) => _draft.series = s,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(_draft.clearFilters),
                    child: const Text('Clear filters'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('apply-filters'),
                      onPressed: () => Navigator.pop(context, _draft),
                      child: Text(
                        'Show $count ${count == 1 ? 'book' : 'books'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
