import 'dart:math';

import '../models/book.dart';
import '../models/reading_session.dart';

DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);
int calendarDaysBetween(DateTime end, DateTime start) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

class ReadingStats {
  ReadingStats(List<Book> books, {this.year, DateTime? today})
    : today = calendarDay(today ?? DateTime.now()) {
    final rated = <int>[];
    for (final b in books.where((b) => b.deletedAt == null)) {
      var matchedBook = false;
      var pass = 0;
      for (final s in b.sessions) {
        final completed =
            !s.isOpen &&
            (year == null ||
                (s.precision != DatePrecision.unknown &&
                    s.endDate!.year == year));
        if (completed) {
          completedReads++;
          matchedBook = true;
          if (pass > 0) rereads++;
          if (s.precision != DatePrecision.unknown) {
            booksByMonth[s.endDate!.month - 1]++;
          }
        }
        if (!s.isOpen) pass++;
        if (s.rating != null && (year == null || completed)) {
          rated.add(s.rating!);
          ratings[s.rating! - 1]++;
        }
        // Old reads have a completion date but no page log. Attribute their
        // known length to that month, never to invented daily activity.
        if (s.progress.isEmpty) {
          final amount = s.isOpen
              ? s.currentPage
              : b.progressTotal ?? s.currentPage;
          if (year == null || completed) {
            if (b.isAudio) {
              minutes += amount;
            } else {
              pages += amount;
            }
            if (completed &&
                !b.isAudio &&
                s.precision != DatePrecision.unknown) {
              pagesByMonth[s.endDate!.month - 1] += amount;
            }
          }
        } else {
          var high = s.progress.first.fromPage ?? 0;
          // Before progress logging existed, this known baseline belongs in
          // all-time totals only, not in a guessed year or day.
          if (year == null) {
            if (b.isAudio) {
              minutes += high;
            } else {
              pages += high;
            }
          }
          for (final entry in s.progress) {
            high = max(high, entry.fromPage ?? high);
            final delta = max(0, entry.page - high);
            high = max(high, entry.page);
            if (delta == 0 || (year != null && entry.date.year != year)) {
              continue;
            }
            activeDays.add(calendarDay(entry.date));
            if (b.isAudio) {
              minutes += delta;
            } else {
              pages += delta;
              pagesByMonth[entry.date.month - 1] += delta;
              pagesByDay.update(
                calendarDay(entry.date),
                (p) => p + delta,
                ifAbsent: () => delta,
              );
            }
          }
        }
      }
      if (matchedBook) {
        booksRead++;
        if (b.author.isNotEmpty) {
          authors.update(b.author, (n) => n + 1, ifAbsent: () => 1);
        }
        for (final tag in b.tags) {
          tags.update(tag, (n) => n + 1, ifAbsent: () => 1);
        }
        formats.update(b.format.label, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    averageRating = rated.isEmpty
        ? null
        : rated.reduce((a, b) => a + b) / rated.length;
  }
  final int? year;
  final DateTime today;
  int booksRead = 0, completedReads = 0, rereads = 0, pages = 0, minutes = 0;
  double? averageRating;
  final booksByMonth = List<int>.filled(12, 0);
  final pagesByMonth = List<int>.filled(12, 0);
  final ratings = List<int>.filled(5, 0);
  final authors = <String, int>{},
      tags = <String, int>{},
      formats = <String, int>{};
  final activeDays = <DateTime>{};
  final pagesByDay = <DateTime, int>{};
  double get pagesPerActiveDay => pagesByDay.isEmpty
      ? 0
      : pagesByDay.values.reduce((a, b) => a + b) / pagesByDay.length;
  int get longestStreak {
    final days = activeDays.toList()..sort();
    var best = 0, current = 0;
    DateTime? previous;
    for (final day in days) {
      current =
          previous != null &&
              DateTime(previous.year, previous.month, previous.day + 1) == day
          ? current + 1
          : 1;
      best = max(best, current);
      previous = day;
    }
    return best;
  }

  int get currentStreak {
    var day = today;
    if (!activeDays.contains(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var streak = 0;
    while (activeDays.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  static double pace(Book book, {DateTime? today}) {
    final session = book.openSession;
    if (session == null || session.progress.isEmpty) return 0;
    final now = calendarDay(today ?? DateTime.now());
    final start = calendarDay(session.progress.first.date);
    final days = max(1, calendarDaysBetween(now, start) + 1);
    var high = session.progress.first.fromPage ?? 0, gained = 0;
    for (final p in session.progress) {
      high = max(high, p.fromPage ?? high);
      gained += max(0, p.page - high);
      high = max(high, p.page);
    }
    return gained / days;
  }

  static DateTime? predictedFinish(Book book, {DateTime? today}) {
    final rate = pace(book, today: today);
    if (rate <= 0 || book.progressTotal == null || book.openSession == null) {
      return null;
    }
    final remaining = max(
      0,
      book.progressTotal! - book.openSession!.currentPage,
    );
    final date = today ?? DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day + (remaining / rate).ceil(),
    );
  }
}
