import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import '../services/library_model.dart';
import 'add_edit_book_screen.dart';

class BookDetailScreen extends StatelessWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final book = library.books.where((b) => b.id == bookId).firstOrNull;

    if (book == null) {
      return const Scaffold(body: Center(child: Text('Book not found')));
    }

    final dateFmt = DateFormat.yMMMd();
    final open = book.openSession;
    final finishedSessions =
        book.sessions.where((s) => !s.isOpen).toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(book.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddEditBookScreen(book: book)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete book?'),
                  content: Text('This removes "${book.title}" and its full reading history.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<LibraryModel>().deleteBook(book.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 116,
                child: book.coverImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(book.coverImagePath!), fit: BoxFit.cover),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.menu_book, size: 32),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: Theme.of(context).textTheme.titleLarge),
                    Text(book.author, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Chip(label: Text(book.status.label), visualDensity: VisualDensity.compact),
                    if (book.timesRead > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Read ${book.timesRead} time${book.timesRead == 1 ? '' : 's'}'),
                      ),
                    if (book.averageRating != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            Text(' ${book.averageRating!.toStringAsFixed(1)} avg'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (open != null) ...[
            _ActionCard(
              title: 'Currently reading',
              subtitle: 'Started ${dateFmt.format(open.startDate)}',
              buttonLabel: 'Finish',
              onPressed: () => _finishSession(context, book),
            ),
            const SizedBox(height: 8),
            _PageProgressTile(book: book, session: open),
          ] else
            _ActionCard(
              title: book.timesRead == 0 ? 'Not started yet' : 'Read again?',
              subtitle: book.timesRead == 0
                  ? 'Log a start date to begin tracking'
                  : 'Start a new reread — the old session stays in your history',
              buttonLabel: book.timesRead == 0 ? 'Start reading' : 'Start reread',
              onPressed: () => _startSession(context, book),
            ),
          if (open == null && book.timesRead > 0 && book.status != BookStatus.dropped)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => context.read<LibraryModel>().markDropped(book),
                child: const Text('Mark as dropped'),
              ),
            ),
          const SizedBox(height: 24),
          Text('Reading history', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (finishedSessions.isEmpty)
            const Text('No completed reads yet.')
          else
            ...finishedSessions.asMap().entries.map((entry) {
              final index = finishedSessions.length - entry.key; // 1-based, most recent = highest
              final s = entry.value;
              return _SessionTile(readNumber: index, session: s, dateFmt: dateFmt);
            }),
        ],
      ),
    );
  }

  Future<void> _startSession(BuildContext context, Book book) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Start date',
    );
    if (picked == null || !context.mounted) return;
    await context.read<LibraryModel>().startReading(book, startDate: picked);
  }

  Future<void> _finishSession(BuildContext context, Book book) async {
    final open = book.openSession;
    if (open == null) return;

    final endDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: open.startDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'End date',
    );
    if (endDate == null || !context.mounted) return;

    final rating = await showDialog<int>(
      context: context,
      builder: (ctx) => _RatingDialog(),
    );
    if (!context.mounted) return;

    await context.read<LibraryModel>().finishReading(book, endDate: endDate, rating: rating);
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle, buttonLabel;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final int readNumber;
  final ReadingSession session;
  final DateFormat dateFmt;

  const _SessionTile({required this.readNumber, required this.session, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(radius: 14, child: Text('$readNumber')),
      title: Text('${dateFmt.format(session.startDate)} → ${dateFmt.format(session.endDate!)}'),
      subtitle: Text('${session.daysTaken} day${session.daysTaken == 1 ? '' : 's'}'),
      trailing: session.rating != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                Text('${session.rating}'),
              ],
            )
          : null,
    );
  }
}

class _PageProgressTile extends StatelessWidget {
  final Book book;
  final ReadingSession session;

  const _PageProgressTile({required this.book, required this.session});

  @override
  Widget build(BuildContext context) {
    final total = book.totalPages;
    final fraction =
        (total != null && total > 0) ? session.currentPage / total : null;

    return Card(
      child: ListTile(
        title: Text(
          total != null
              ? 'Page ${session.currentPage} of $total'
              : 'Page ${session.currentPage}',
        ),
        subtitle: fraction != null
            ? Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(value: fraction.clamp(0, 1)),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Set current page',
          onPressed: () => _editPage(context),
        ),
        onTap: () => _editPage(context),
      ),
    );
  }

  Future<void> _editPage(BuildContext context) async {
    final controller = TextEditingController(text: '${session.currentPage}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Current page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: book.totalPages != null ? 'of ${book.totalPages} pages' : 'Page number',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, page);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await context.read<LibraryModel>().updatePage(book, result);
    }
  }
}

class _RatingDialog extends StatefulWidget {
  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int? _rating;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate this read (optional)'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final value = i + 1;
          return IconButton(
            icon: Icon(
              _rating != null && value <= _rating! ? Icons.star : Icons.star_border,
              color: Colors.amber,
            ),
            onPressed: () => setState(() => _rating = value),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _rating),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
