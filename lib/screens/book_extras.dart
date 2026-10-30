import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../services/library_model.dart';
import '../services/reading_stats.dart';
import '../widgets/ledger.dart';

class BookExtras extends StatelessWidget {
  const BookExtras({super.key, required this.book});
  final Book book;
  Future<void> _quote(BuildContext context) async {
    final library = context.read<LibraryModel>();
    final text = TextEditingController(), page = TextEditingController();
    final form = GlobalKey<FormState>();
    final quote = await showDialog<BookQuote>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save a quote or highlight'),
        scrollable: true,
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: text,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Quote / highlight',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter some text.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: page,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: book.isAudio
                      ? 'Minute (optional)'
                      : 'Page (optional)',
                ),
                validator: (v) => v == null || v.isEmpty
                    ? null
                    : int.tryParse(v) == null ||
                          int.parse(v) < 0 ||
                          (book.progressTotal != null &&
                              int.parse(v) > book.progressTotal!)
                    ? 'Use a location within the book.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  ctx,
                  BookQuote(
                    id: const Uuid().v4(),
                    text: text.text.trim(),
                    page: int.tryParse(page.text),
                  ),
                );
              }
            },
            child: const Text('Save quote'),
          ),
        ],
      ),
    );
    text.dispose();
    page.dispose();
    if (quote != null) await library.addQuote(book, quote);
  }

  @override
  Widget build(BuildContext context) {
    final rate = ReadingStats.pace(book),
        finish = ReadingStats.predictedFinish(book);
    final details = <String>[
      if (book.subtitle.isNotEmpty) book.subtitle,
      if (book.isbn.isNotEmpty) 'ISBN ${book.isbn}',
      [
        book.publisher,
        book.year?.toString() ?? '',
        book.language,
      ].where((v) => v.isNotEmpty).join(' · '),
      if (book.series.isNotEmpty) '${book.series} ${book.seriesNumber}',
      book.tags.join(' · '),
      if (book.dropReason.isNotEmpty) 'Set aside: ${book.dropReason}',
    ].where((v) => v.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        if (details.isNotEmpty) ...[
          const SectionHeading('book details'),
          const SizedBox(height: 12),
          ...details.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(d),
            ),
          ),
        ],
        if (book.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHeading('personal notes'),
          const SizedBox(height: 12),
          SelectableText(book.notes),
        ],
        if (book.openSession != null) ...[
          const SizedBox(height: 20),
          const SectionHeading('pace'),
          const SizedBox(height: 12),
          Text(
            rate == 0
                ? 'Log progress to discover your pace and estimated finish date.'
                : '${rate.toStringAsFixed(1)} ${book.progressUnit} / day${finish == null ? '' : ' · estimated finish ${finish.toString().substring(0, 10)}'}',
          ),
          if (book.status != BookStatus.reading)
            TextButton(
              onPressed: () => context.read<LibraryModel>().setStatus(
                book,
                BookStatus.reading,
              ),
              child: const Text('Resume reading'),
            ),
        ],
        const SizedBox(height: 24),
        SectionHeading(
          'quotes & highlights',
          trailing: IconButton(
            tooltip: 'Add quote',
            onPressed: () => _quote(context),
            icon: const Icon(Icons.add),
          ),
        ),
        if (book.quotes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Keep a passage here. Quotes are searchable from your library.',
            ),
          ),
        ...book.quotes.map(
          (q) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: SelectableText(q.text),
            subtitle: q.page == null
                ? null
                : Text(
                    '${book.isAudio ? 'Time' : 'Page'} ${book.progressLabel(q.page!)}',
                  ),
            trailing: IconButton(
              tooltip: 'Remove quote',
              icon: const Icon(Icons.close),
              onPressed: () async {
                final library = context.read<LibraryModel>();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove quote?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Keep'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await library.deleteQuote(book, q.id);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeading('progress log'),
        if (book.sessions.every((s) => s.progress.isEmpty))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Each page or listening-time change will be dated here.',
            ),
          ),
        ...book.sessions.reversed.expand(
          (s) => s.progress.reversed.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${book.isAudio ? 'Time' : 'Page'} ${book.progressLabel(p.page)}',
              ),
              subtitle: Text(p.date.toLocal().toString().split('.').first),
            ),
          ),
        ),
      ],
    );
  }
}
