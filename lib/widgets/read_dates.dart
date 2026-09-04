import 'package:intl/intl.dart';

import '../models/reading_session.dart';

/// How a read's dates are worded, in one place, so the library list, the
/// book screen and the editor never disagree about what is known.
///
/// Everything here is lowercase to match the log's utility voice.

final _day = DateFormat('d MMM yyyy');
final _dayShort = DateFormat('d MMM');
final _month = DateFormat('MMM yyyy');

String _fmt(DateFormat f, DateTime d) => f.format(d).toLowerCase();

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// The span of a finished read: `11 jun 2017 → 25 jun 2017`,
/// `jun 2017 → aug 2017`, `jun 2017`, or `date unknown`.
String readSpan(ReadingSession session) =>
    readSpanOf(session.startDate, session.endDate, session.precision);

/// The same wording over a loose pair of dates, for the editor, which is
/// holding values that are not on a session yet.
String readSpanOf(DateTime start, DateTime? end, DatePrecision precision) {
  switch (precision) {
    case DatePrecision.unknown:
      return 'date unknown';
    case DatePrecision.approximate:
      if (end == null || _sameMonth(start, end)) return _fmt(_month, start);
      return '${_fmt(_month, start)}  →  ${_fmt(_month, end)}';
    case DatePrecision.exact:
      if (end == null) return _fmt(_day, start);
      return '${_fmt(_day, start)}  →  ${_fmt(_day, end)}';
  }
}

/// The line under a span: how long it took, or why that can't be said.
String readSpanNote(ReadingSession session) {
  final days = session.daysTaken;
  return switch (session.precision) {
    DatePrecision.unknown => 'no dates recorded',
    DatePrecision.approximate => 'month only',
    DatePrecision.exact =>
      days == null ? 'dates only' : '$days day${days == 1 ? '' : 's'}',
  };
}

/// How a finished read reads in a list row. [short] drops the year when the
/// read finished this year, which only applies to an exact date.
String finishedPhrase(ReadingSession session, {bool short = true}) {
  final end = session.endDate;
  switch (session.precision) {
    case DatePrecision.unknown:
      return 'finished, date unknown';
    case DatePrecision.approximate:
      return 'finished around ${_fmt(_month, end ?? session.startDate)}';
    case DatePrecision.exact:
      if (end == null) return 'finished';
      final thisYear = short && end.year == DateTime.now().year;
      return 'finished ${_fmt(thisYear ? _dayShort : _day, end)}';
  }
}

/// How an open read reads.
String startedPhrase(ReadingSession session, {bool short = true}) {
  switch (session.precision) {
    case DatePrecision.unknown:
      return 'start date unknown';
    case DatePrecision.approximate:
      return 'started around ${_fmt(_month, session.startDate)}';
    case DatePrecision.exact:
      final thisYear = short && session.startDate.year == DateTime.now().year;
      return 'started ${_fmt(thisYear ? _dayShort : _day, session.startDate)}';
  }
}

/// A single date as the editor shows it, at whatever precision applies.
String dateAtPrecision(DateTime date, DatePrecision precision) =>
    switch (precision) {
      DatePrecision.unknown => 'not recorded',
      DatePrecision.approximate => _fmt(_month, date),
      DatePrecision.exact => _fmt(_day, date),
    };

/// Approximate dates keep only the month, so a start snaps to the first of
/// it and an end to the last — the day the user happened to tap in the
/// picker is not information.
DateTime snapToMonthStart(DateTime d) => DateTime(d.year, d.month);
DateTime snapToMonthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);
