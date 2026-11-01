import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import '../services/library_model.dart';
import '../services/theme_notifier.dart';
import '../services/reading_stats.dart';
import '../theme/tokens.dart';
import '../widgets/book_row.dart' show plateLetterFor;
import '../widgets/ledger.dart';
import '../widgets/read_dates.dart';
import '../widgets/read_format_fields.dart';
import '../widgets/set_page_dialog.dart';
import '../widgets/spine.dart';
import 'add_edit_book_screen.dart';
import 'book_extras.dart';

/// One book, and every pass you have made through it.
///
/// The history is the reason this app exists, so it is a real timeline —
/// numbered from the first read, running down the page with the most
/// recent at the top — rather than a list of identical rows.
class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({
    super.key,
    required this.bookId,
    this.updateProgress = false,
  });

  final String bookId;
  final bool updateProgress;
  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  String get bookId => widget.bookId;
  @override
  void initState() {
    super.initState();
    if (widget.updateProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final book = context.read<LibraryModel>().byId(bookId);
        if (book != null) unawaited(showSetPageDialog(context, book));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final matches = library.books.where((b) => b.id == bookId);

    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          headline: 'That book is gone',
          body:
              'It was deleted, or the library was replaced by an import '
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
              MaterialPageRoute<void>(
                builder: (_) => AddEditBookScreen(book: book),
              ),
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
          const SizedBox(height: 16),
          DropdownButtonFormField<BookStatus>(
            isExpanded: true,
            key: ValueKey('status-${book.status.name}'),
            initialValue: book.status,
            decoration: const InputDecoration(labelText: 'Move to shelf'),
            items: BookStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (s) {
              if (s != null) unawaited(library.setStatus(book, s));
            },
          ),
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.c.inkMuted),
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
          BookExtras(book: book),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Book book) async {
    final library = context.read<LibraryModel>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this book?'),
        content: Text(
          '"${book.title}" and all ${book.timesRead} logged '
          'read${book.timesRead == 1 ? '' : 's'} move to trash for 30 days. You can restore it in Settings.',
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
    if (await library.deleteBook(book.id)) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Book moved to trash.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => library.restoreBook(book.id),
          ),
        ),
      );
    }
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
    final facts = <String>[
      if (book.progressTotal != null)
        '${book.progressLabel(book.progressTotal!)} ${book.isAudio ? 'hours' : 'pages'}',
      if (avg != null)
        book.timesRead > 1
            ? '${avg.toStringAsFixed(1)} avg over ${book.timesRead} reads'
            : 'rated ${avg.toStringAsFixed(1)}',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Spine(book: book, height: 116, width: 13),
        const SizedBox(width: Space.step),
        Hero(
          tag: 'cover-${book.id}',
          child: SizedBox(
            width: 80,
            height: 116,
            child: ClipRRect(
              borderRadius: Radii.cover,
              child:
                  book.coverImagePath != null &&
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
                  // One string with its own separators: as separate Wrap
                  // children these facts sat a single space apart and read
                  // as one run-on phrase.
                  if (facts.isNotEmpty) Meta(facts.join('  ·  '), maxLines: 2),
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
    final total = book.progressTotal;
    final fraction = (total != null && total > 0)
        ? session.currentPage / total
        : null;
    final exact = session.precision == DatePrecision.exact;
    final days = calendarDaysBetween(DateTime.now(), session.startDate) + 1;

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
              if (exact) Meta('day $days'),
            ],
          ),
          const SizedBox(height: Space.step),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                book.progressLabel(session.currentPage),
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
              Flexible(
                child: Meta(
                  total != null
                      ? 'of ${book.progressLabel(total)} ${book.isAudio ? 'hours' : 'pages'}'
                      : book.progressUnit,
                  size: 13,
                ),
              ),
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
          Meta(startedPhrase(session, short: false)),
          TextButton.icon(
            key: const ValueKey('edit-open-read-format'),
            onPressed: () async {
              final library = context.read<LibraryModel>();
              final edition = await showReadFormatDialog(
                context,
                book,
                session: session,
              );
              if (edition == null) return;
              await library.editSession(
                book,
                session,
                rating: session.rating,
                format: edition.format,
                totalLength: edition.totalLength,
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(session.format!.label),
          ),
          const SizedBox(height: Space.gutter),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => showSetPageDialog(context, book),
                  child: Text(book.isAudio ? 'Set time' : 'Set page'),
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

    final endDate = session.precision == DatePrecision.unknown
        ? today
        : await showDatePicker(
            context: context,
            initialDate: today,
            firstDate: firstSelectable,
            lastDate: today.add(const Duration(days: 1)),
            helpText: session.precision == DatePrecision.approximate
                ? 'Finished — any day that month'
                : 'Finished on',
          );
    if (endDate == null || !context.mounted) return;

    final rating = await showDialog<int?>(
      context: context,
      builder: (_) => const _RatingDialog(),
    );
    if (!context.mounted) return;

    await library.finishReading(
      book,
      endDate: session.precision == DatePrecision.approximate
          ? snapToMonthEnd(endDate)
          : endDate,
      rating: rating,
    );
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
    final precision = context.read<ThemeNotifier>().defaultPrecision;
    final edition = await showReadFormatDialog(context, book);
    if (edition == null || !context.mounted) return;
    final today = DateUtils.dateOnly(DateTime.now());
    if (precision == DatePrecision.unknown) {
      await library.startReading(
        book,
        startDate: today,
        precision: precision,
        format: edition.format,
        totalLength: edition.totalLength,
      );
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(1900),
      lastDate: today.add(const Duration(days: 1)),
      helpText: 'Started on',
    );
    if (picked == null) return;
    await library.startReading(
      book,
      startDate: precision == DatePrecision.approximate
          ? snapToMonthStart(picked)
          : picked,
      precision: precision,
      format: edition.format,
      totalLength: edition.totalLength,
    );
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
          decoration: BoxDecoration(color: c.accent, borderRadius: Radii.chip),
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

    return Semantics(
      button: true,
      label:
          'Read $readNumber, ${session.format!.label}, ${readSpan(session)}, '
          '${session.rating == null ? 'not rated' : 'rated ${session.rating} '
                    'out of 5'}. Edit this read.',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('read-${session.id}'),
        onTap: () => _editRead(context),
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
                    Meta(readSpan(session), color: c.ink, size: 12),
                    const SizedBox(height: Space.tight),
                    Meta(
                      '${session.format!.label} · ${readSpanNote(session)}',
                      size: 11,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.snug),
              // The unrated case has to show something, or there is no sign
              // a rating can be given at all.
              if (session.rating != null)
                RatingPips(rating: session.rating!)
              else
                Meta('not rated', size: 11, color: c.inkFaint),
              const SizedBox(width: Space.snug),
              Icon(Icons.edit_outlined, size: 15, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editRead(BuildContext context) async {
    final library = context.read<LibraryModel>();
    final result = await showDialog<_ReadEdit>(
      context: context,
      builder: (_) =>
          _EditReadDialog(book: book, session: session, readNumber: readNumber),
    );
    if (result == null) return;
    await library.editSession(
      book,
      session,
      startDate: result.start,
      endDate: result.end,
      rating: result.rating,
      precision: result.precision,
      format: result.edition.format,
      totalLength: result.edition.totalLength,
    );
  }
}

/// What came back from the read editor.
class _ReadEdit {
  const _ReadEdit(
    this.start,
    this.end,
    this.rating,
    this.precision,
    this.edition,
  );
  final DateTime start;
  final DateTime end;
  final int? rating;
  final DatePrecision precision;
  final ReadEdition edition;
}

/// Edits one finished read. Rating lives here rather than only in the
/// finish flow, so skipping it at the time is no longer permanent.
class _EditReadDialog extends StatefulWidget {
  const _EditReadDialog({
    required this.book,
    required this.session,
    required this.readNumber,
  });

  final Book book;

  final ReadingSession session;
  final int readNumber;

  @override
  State<_EditReadDialog> createState() => _EditReadDialogState();
}

class _EditReadDialogState extends State<_EditReadDialog> {
  final _form = GlobalKey<FormState>();
  late ReadEdition _edition = ReadEdition(
    widget.session.format!,
    widget.session.totalLength,
  );
  late DateTime _start = DateUtils.dateOnly(widget.session.startDate);
  late DateTime _end = DateUtils.dateOnly(
    widget.session.endDate ?? widget.session.startDate,
  );
  late int? _rating = widget.session.rating;
  late DatePrecision _precision = widget.session.precision;

  Future<void> _pickDates() async {
    final approximate = _precision == DatePrecision.approximate;
    final today = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _start.isAfter(today) ? today : _start,
        end: _end.isAfter(today) ? today : _end,
      ),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: approximate
          ? 'Read ${widget.readNumber} — any day in each month'
          : 'Read ${widget.readNumber}',
      saveText: 'Use these dates',
    );
    if (range == null) return;
    setState(() {
      _start = approximate ? snapToMonthStart(range.start) : range.start;
      _end = approximate ? snapToMonthEnd(range.end) : range.end;
    });
  }

  /// Switching to approximate re-snaps to whole months, so no stray day
  /// survives the change.
  void _changePrecision(DatePrecision next) {
    setState(() {
      _precision = next;
      if (next == DatePrecision.approximate) {
        _start = snapToMonthStart(_start);
        _end = snapToMonthEnd(_end);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = _end.difference(_start).inDays + 1;

    return AlertDialog(
      scrollable: true,
      titlePadding: const EdgeInsets.fromLTRB(
        Space.block,
        Space.block,
        Space.block,
        0,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        Space.block,
        Space.step,
        Space.block,
        0,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Meta('read ${widget.readNumber}', size: 11),
          const SizedBox(height: Space.tight),
          const Text('Edit this read'),
        ],
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReadFormatFields(
              initial: ReadEdition(
                widget.session.format!,
                widget.session.totalLength,
              ),
              pageLength: widget.book.totalPages,
              audioLength: widget.book.totalMinutes,
              hasProgress:
                  widget.session.currentPage > 0 ||
                  widget.session.progress.isNotEmpty,
              onChanged: (v) => _edition = v,
            ),
            const SizedBox(height: Space.gutter),
            const Meta('dates'),
            const SizedBox(height: Space.tight),
            SegmentedChoice<DatePrecision>(
              values: DatePrecision.values,
              value: _precision,
              labelOf: (p) => p.label,
              onChanged: _changePrecision,
            ),
            if (_precision == DatePrecision.unknown) ...[
              const SizedBox(height: Space.snug),
              Text(
                'No dates are kept for this read. It still counts towards your '
                'totals.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.inkMuted),
              ),
            ] else ...[
              const SizedBox(height: Space.snug),
              Semantics(
                button: true,
                label:
                    'Dates, ${readSpanOf(_start, _end, _precision)}. '
                    'Change dates.',
                excludeSemantics: true,
                child: InkWell(
                  onTap: _pickDates,
                  borderRadius: Radii.field,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: kTapTarget),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.step,
                      vertical: Space.snug,
                    ),
                    decoration: BoxDecoration(
                      color: c.well,
                      borderRadius: Radii.field,
                      border: Border.all(color: c.rule),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Meta(
                                readSpanOf(_start, _end, _precision),
                                color: c.ink,
                                size: 12,
                              ),
                              const SizedBox(height: 2),
                              Meta(
                                _precision == DatePrecision.approximate
                                    ? 'month only'
                                    : '$days day${days == 1 ? '' : 's'}',
                                size: 11,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.snug),
                        Icon(Icons.event_outlined, size: 16, color: c.inkMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: Space.gutter),
            const Meta('rating'),
            const SizedBox(height: Space.tight),
            StarRating(
              value: _rating,
              onChanged: (v) => setState(() => _rating = v),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.step,
        Space.gutter,
        Space.gutter,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ReadEdit(_start, _end, _rating, _precision, _edition),
            );
          },
          child: const Text('Save read'),
        ),
      ],
    );
  }
}

/// Offered when a read is closed. Skipping here is no longer permanent —
/// the read can be rated later from the reading history.
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
      scrollable: true,
      title: const Text('Rate this read'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Optional, and it belongs to this read alone — a reread can score '
            'differently. You can set or change it later from the reading '
            'history.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Space.step),
          StarRating(
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
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
