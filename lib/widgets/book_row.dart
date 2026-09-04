import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import '../theme/tokens.dart';
import 'ledger.dart';
import 'read_dates.dart';
import 'spine.dart';

/// One line of the log.
///
/// Reading order across the row: how far you are ([Spine]), which book
/// (cover, title, author), where that leaves you and how many times you
/// have been here ([metaLine]), and — only while a read is open — the page
/// stamp, which is the app's daily action and so is the only control in
/// the row besides the row itself.
class BookRow extends StatelessWidget {
  const BookRow({
    super.key,
    required this.book,
    required this.onTap,
    this.onSetPage,
  });

  final Book book;
  final VoidCallback onTap;

  /// Only supplied for books with an open read.
  final VoidCallback? onSetPage;

  static const _coverWidth = 46.0;
  static const _coverHeight = 66.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = Theme.of(context).textTheme;
    final open = book.openSession;

    return Semantics(
      button: true,
      label: '${book.title}${book.author.isEmpty ? '' : ', ${book.author}'}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            14,
            Space.step,
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spine(book: book, height: _coverHeight, width: 12),
              const SizedBox(width: Space.snug),
              _Cover(book: book, width: _coverWidth, height: _coverHeight),
              const SizedBox(width: Space.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(height: 1.15),
                    ),
                    if (book.author.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
                    ],
                    const SizedBox(height: Space.snug),
                    Meta(
                      metaLine(book),
                      color: c.inkMuted,
                      size: 11,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.step),
              if (open != null && onSetPage != null)
                _PageStamp(book: book, onTap: onSetPage!)
              else
                _Verdict(book: book),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status of a book, in the log's own voice.
///
/// This is where rereads are spelled out. The spine used to carry them as
/// notches and nobody could read them, so the count says itself here, and
/// the line never repeats what the page stamp already shows.
String metaLine(Book book) {
  final open = book.openSession;
  final total = book.totalPages;
  final parts = <String>[];
  final again = 'read ${book.timesRead}x';

  switch (book.status) {
    case BookStatus.reading:
      if (open == null) return 'no open read';
      // A reread names which pass this is, numbered the same way the book's
      // own reading history numbers them. The "#" matters: bare "read 3"
      // sits one tab away from "read 3x", which means something else.
      if (book.timesRead > 0) parts.add('read #${book.timesRead + 1}');
      if (total != null && total > 0) {
        parts.add('${((open.currentPage / total) * 100).round()}%');
      }
      parts.add(startedPhrase(open));

    case BookStatus.toRead:
      if (book.timesRead > 0) parts.add(again);
      parts.add(
        total != null && total > 0 ? '$total pages' : 'page count not set',
      );

    case BookStatus.read:
      final closed = book.sessions.where((s) => s.endDate != null).toList()
        ..sort((a, b) => b.endDate!.compareTo(a.endDate!));
      if (closed.isEmpty) return 'finished';
      final last = closed.first;
      if (book.isReread) parts.add(again);
      parts.add(finishedPhrase(last));
      // How long it took only fits alongside the date on a single read, and
      // only when the days are known at all.
      if (!book.isReread && last.daysTaken != null) {
        final days = last.daysTaken!;
        parts.add('$days day${days == 1 ? '' : 's'}');
      }

    case BookStatus.dropped:
      if (book.timesRead > 0) parts.add(again);
      if (open != null && open.currentPage > 0) {
        parts.add('stopped at p. ${open.currentPage}');
        if (open.precision != DatePrecision.unknown) {
          parts.add(dateAtPrecision(open.startDate, open.precision));
        }
      } else {
        parts.add('dropped');
      }
  }
  return parts.join(' · ');
}

/// How far the user has turned text up, capped so a fixed-width control
/// can be sized from it without running off the row.
double scaleFactor(BuildContext context, {double max = 2.0}) {
  final scaler = MediaQuery.textScalerOf(context);
  return (scaler.scale(12) / 12).clamp(1.0, max);
}

/// The daily action, one tap from the list: set where you are.
class _PageStamp extends StatelessWidget {
  const _PageStamp({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final page = book.openSession?.currentPage ?? 0;
    final total = book.totalPages;

    return Semantics(
      button: true,
      label: total != null
          ? 'Set current page, now $page of $total'
          : 'Set current page, now $page',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chip,
        child: Container(
          // Grows with the text scale, or "/662" ellipsised to "/6…".
          width: 56 * scaleFactor(context, max: 1.8),
          constraints: const BoxConstraints(minHeight: kTapTarget),
          padding: const EdgeInsets.symmetric(vertical: Space.snug),
          decoration: BoxDecoration(
            color: c.well,
            borderRadius: Radii.chip,
            border: Border.all(color: c.rule),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$page',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Faces.utility,
                  fontSize: 16,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                  fontFeatures: kTabular,
                ),
              ),
              const SizedBox(height: 2),
              Meta(
                total != null ? '/$total' : 'page',
                size: 11,
                color: c.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a closed book was worth, averaged across every read of it.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final avg = book.averageRating;
    if (avg == null) return const SizedBox(width: Space.tight);

    // Just the figure. The read count lives in the meta line now.
    return Text(
      avg.toStringAsFixed(1),
      style: TextStyle(
        fontFamily: Faces.utility,
        fontSize: 15,
        height: 1.1,
        fontWeight: FontWeight.w700,
        color: c.ink,
        fontFeatures: kTabular,
      ),
    );
  }
}

/// A missing cover still has to say which book it is, so it carries the
/// title's initials rather than the same generic book glyph on every row.
class _Cover extends StatelessWidget {
  const _Cover({required this.book, required this.width, required this.height});

  final Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final path = book.coverImagePath;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: Radii.cover,
        child: path != null && File(path).existsSync()
            ? Image.file(File(path), fit: BoxFit.cover)
            : Container(
                color: c.plate,
                alignment: Alignment.center,
                child: Text(
                  plateLetterFor(book.title),
                  style: TextStyle(
                    fontFamily: Faces.display,
                    fontSize: width * 0.62,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: c.inkFaint,
                  ),
                ),
              ),
      ),
    );
  }
}

/// A single letter for a book with no cover, taken from the first word
/// that is not an article. Two letters were tried first and spelled real
/// words — "The Name of the Wind" came out as "NO".
String plateLetterFor(String title) {
  const skip = {'a', 'an', 'the'};
  final words = title
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();
  final pick = words.firstWhere(
    (w) => !skip.contains(w.toLowerCase()),
    orElse: () => words.isEmpty ? '?' : words.first,
  );
  return String.fromCharCodes(pick.runes.take(1)).toUpperCase();
}
