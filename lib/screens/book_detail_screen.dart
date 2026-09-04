import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import '../services/library_model.dart';
import '../theme/tokens.dart';
import '../widgets/book_row.dart' show plateLetterFor;
import '../widgets/ledger.dart';
import '../widgets/set_page_dialog.dart';
import '../widgets/spine.dart';
import 'add_edit_book_screen.dart';

/// One book, and every pass you have made through it.
///
/// The history is the reason this app exists, so it is a real timeline —
/// numbered from the first read, running down the page with the most
/// recent at the top — rather than a list of identical rows.
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final matches = library.books.where((b) => b.id == bookId);

    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          headline: 'That book is gone',
          body: 'It was deleted, or the library was replaced by an import '
              'while this screen was open.',
          actionLabel: 'Back to library',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    final book = matches.first;
    final open = book.openSession;
    final history = book.sessions.where((s) => !s.isOpen).toList()
      ..sort((a, b) => b.endDate!.compareTo(a.endDate!));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit book',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddEditBookScreen(book: book)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete book',
            onPressed: () => _confirmDelete(context, book),
          ),
          const SizedBox(width: Space.tight),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.snug,
          Space.gutter,
          Space.section,
        ),
        children: [
          _Identity(book: book),
          const SizedBox(height: Space.block),
          if (open != null)
            _OpenRead(book: book, session: open)
          else
            _ClosedRead(book: book),
          const SizedBox(height: Space.block),
          SectionHeading(
            'reading history',
            trailing: Meta(
              history.isEmpty
                  ? '0 reads'
                  : '${history.length} read${history.length == 1 ? '' : 's'}',
            ),
          ),
          const SizedBox(height: Space.step),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.tight),
              child: Text(
                open == null
                    ? 'No finished reads yet. Start one above and it will be '
                        'logged here when you close it.'
                    : 'This read is still open. It joins the history once you '
                        'finish it.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: context.c.inkMuted),
              ),
            )
          else
            ...List.generate(history.length * 2 - 1, (i) {
              if (i.isOdd) {
                return Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Container(height: 1, color: context.c.rule),
                );
              }
              final index = i ~/ 2;
              return _SessionEntry(
                book: book,
                session: history[index],
                // Numbered from the first read, so read 1 stays read 1.
                readNumber: history.length - index,
              );
            }),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Book book) async {
    final library = context.read<LibraryModel>();
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this book?'),
        content: Text(
          '"${book.title}" and all ${book.timesRead} logged '
          'read${book.timesRead == 1 ? '' : 's'} go with it. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.c.danger,
              foregroundColor: ctx.c.onInk,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete book'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await library.deleteBook(book.id);
    navigator.pop();
  }
}

/// Cover, spine and title, in the same reading order as a list row so the
/// screen feels like the row opened up rather than a different product.
class _Identity extends StatelessWidget {
  const _Identity({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    final avg = book.averageRating;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Spine(book: book, height: 116, width: 13),
        const SizedBox(width: Space.step),
        SizedBox(
          width: 80,
          height: 116,
          child: ClipRRect(
            borderRadius: Radii.cover,
            child: book.coverImagePath != null &&
                    File(book.coverImagePath!).existsSync()
                ? Image.file(File(book.coverImagePath!), fit: BoxFit.cover)
                : Container(
                    color: c.plate,
                    alignment: Alignment.center,
                    child: Text(
                      plateLetterFor(book.title),
                      style: TextStyle(
                        fontFamily: Faces.display,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: c.inkFaint,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: Space.gutter),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title, style: t.titleLarge),
              if (book.author.isNotEmpty) ...[
                const SizedBox(height: Space.tight),
                Text(book.author, style: t.bodySmall),
              ],
              const SizedBox(height: Space.step),
              Wrap(
                spacing: Space.snug,
                runSpacing: Space.snug,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusTag(book.status.label.toLowerCase()),
                  if (book.totalPages != null)
                    Meta('${book.totalPages} pages'),
                  if (avg != null)
                    Meta(
                      book.timesRead > 1
                          ? '${avg.toStringAsFixed(1)} avg over '
                              '${book.timesRead} reads'
                          : 'rated ${avg.toStringAsFixed(1)}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The open read: where you are, and the two things you can do about it.
class _OpenRead extends StatelessWidget {
  const _OpenRead({required this.book, required this.session});

  final Book book;
  final ReadingSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final total = book.totalPages;
    final fraction =
        (total != null && total > 0) ? session.currentPage / total : null;
    final started =
        DateFormat('d MMM yyyy').format(session.startDate).toLowerCase();
    final days = DateTime.now().difference(session.startDate).inDays + 1;

    return Panel(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Meta(
                  'read #${book.timesRead + 1} · open',
                  color: c.inkMuted,
                ),
              ),
              Meta('day $days'),
            ],
          ),
          const SizedBox(height: Space.step),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${session.currentPage}',
                style: TextStyle(
                  fontFamily: Faces.utility,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: c.ink,
                  fontFeatures: kTabular,
                ),
              ),
              const SizedBox(width: Space.snug),
              Meta(total != null ? 'of $total pages' : 'pages in', size: 13),
              const Spacer(),
              if (fraction != null)
                Meta(
                  '${(fraction.clamp(0, 1) * 100).round()}%',
                  size: 13,
                  color: c.ink,
                  weight: FontWeight.w700,
                ),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: Space.step),
            _ProgressRule(value: fraction.clamp(0, 1).toDouble()),
          ],
          const SizedBox(height: Space.step),
          Meta('started $started'),
          const SizedBox(height: Space.gutter),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => showSetPageDialog(context, book),
                  child: const Text('Set page'),
                ),
              ),
              const SizedBox(width: Space.step),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _finish(context),
                  child: const Text('Finish read'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _finish(BuildContext context) async {
    final library = context.read<LibraryModel>();

    // Every date here is normalized to midnight (date-only). Mixing a
    // date-only value with DateTime.now()'s time-of-day is what made the
    // end-date picker reject "today" as out of range on same-day sessions.
    final today = DateUtils.dateOnly(DateTime.now());
    final startDay = DateUtils.dateOnly(session.startDate);
    final firstSelectable = startDay.isAfter(today) ? today : startDay;

    final endDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: firstSelectable,
      lastDate: today.add(const Duration(days: 1)),
      helpText: 'Finished on',
    );
    if (endDate == null || !context.mounted) return;

    final rating = await showDialog<int?>(
      context: context,
      builder: (_) => const _RatingDialog(),
    );
    if (!context.mounted) return;

    await library.finishReading(book, endDate: endDate, rating: rating);
  }
}

/// No open read: either this book has never been started, or it is waiting
/// for another pass.
class _ClosedRead extends StatelessWidget {
  const _ClosedRead({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final started = book.timesRead > 0;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Meta(started ? 'no read open' : 'never started'),
          const SizedBox(height: Space.snug),
          Text(
            started
                ? 'Starting again opens a new session. The reads below stay '
                    'exactly as they are.'
                : 'Pick the day you started and this book moves to Reading.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Space.gutter),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _start(context),
              child: Text(started ? 'Start a reread' : 'Start reading'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final library = context.read<LibraryModel>();
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(1900),
      lastDate: today.add(const Duration(days: 1)),
      helpText: 'Started on',
    );
    if (picked == null) return;
    await library.startReading(book, startDate: picked);
  }
}

/// Squared-off progress in the accent colour. The stock indicator's
/// rounded caps and 4px height read as a generic loading bar; this reads
/// as a level.
class _ProgressRule extends StatelessWidget {
  const _ProgressRule({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 4,
        decoration: BoxDecoration(color: c.well, borderRadius: Radii.chip),
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: Motion.fill,
          curve: Motion.curve,
          width: constraints.maxWidth * value,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: Radii.chip,
          ),
        ),
      ),
    );
  }
}

/// One completed pass. Entries are ruled apart the same way the library
/// list is, so the two surfaces read as the same document.
class _SessionEntry extends StatelessWidget {
  const _SessionEntry({
    required this.book,
    required this.session,
    required this.readNumber,
  });

  final Book book;
  final ReadingSession session;
  final int readNumber;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fmt = DateFormat('d MMM yyyy');
    final days = session.daysTaken;

    return Semantics(
      button: true,
      label: 'Read $readNumber, ${fmt.format(session.startDate)} to '
          '${fmt.format(session.endDate!)}. Edit dates.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _editDates(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: kTapTarget),
          padding: const EdgeInsets.symmetric(vertical: Space.step),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '$readNumber',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Faces.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: c.inkMuted,
                    fontFeatures: kTabular,
                  ),
                ),
              ),
              const SizedBox(width: Space.step),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Meta(
                      '${fmt.format(session.startDate).toLowerCase()}'
                      '  →  '
                      '${fmt.format(session.endDate!).toLowerCase()}',
                      color: c.ink,
                      size: 12,
                    ),
                    const SizedBox(height: Space.tight),
                    Meta(
                      days == null
                          ? 'dates only'
                          : '$days day${days == 1 ? '' : 's'}',
                      size: 11,
                    ),
                  ],
                ),
              ),
              if (session.rating != null) ...[
                const SizedBox(width: Space.snug),
                RatingPips(rating: session.rating!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editDates(BuildContext context) async {
    final library = context.read<LibraryModel>();
    final today = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: DateUtils.dateOnly(session.startDate),
        end: DateUtils.dateOnly(session.endDate ?? session.startDate),
      ),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Read $readNumber',
      saveText: 'Save dates',
    );
    if (range == null) return;
    session.startDate = range.start;
    session.endDate = range.end;
    await library.updateBook(book);
  }
}

/// Rating input keeps the familiar five-star shape, but in ink — a second
/// bright colour would compete with the spine, which is the only thing on
/// screen allowed to be the accent.
class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int? _rating;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return AlertDialog(
      title: const Text('Rate this read'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Optional, and it belongs to this read alone — a reread can score '
            'differently.',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Space.step),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final value = i + 1;
              final on = _rating != null && value <= _rating!;
              return IconButton(
                icon: Icon(on ? Icons.star : Icons.star_border, size: 26),
                color: on ? c.ink : c.inkFaint,
                tooltip: '$value out of 5',
                onPressed: () => setState(() => _rating = value),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip rating'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _rating),
          child: const Text('Save read'),
        ),
      ],
    );
  }
}
