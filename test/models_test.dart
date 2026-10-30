import 'dart:convert';

import 'package:book_companion/models/book.dart';
import 'package:book_companion/models/reading_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Every book, quote, progress and session field round-trips', () {
    final created = DateTime(2025, 1, 1), updated = DateTime(2026, 2, 1);
    final original = Book(
      id: 'b',
      title: 'Élan',
      author: 'A',
      coverImagePath: '/covers/a.jpg',
      status: BookStatus.onHold,
      format: BookFormat.audiobook,
      totalMinutes: 1250,
      totalPages: 350,
      subtitle: 'A story',
      isbn: '9781234567890',
      publisher: 'P',
      year: 2025,
      language: 'fr',
      series: 'S',
      seriesNumber: '2.5',
      tags: ['memoir', 'travel'],
      notes: 'N',
      dropReason: 'R',
      createdAt: created,
      updatedAt: updated,
      deletedAt: updated,
      quotes: [const BookQuote(id: 'q', text: 'Remember this', page: 42)],
      sessions: [
        ReadingSession(
          id: 's',
          startDate: created,
          endDate: updated,
          rating: 4,
          currentPage: 1250,
          precision: DatePrecision.approximate,
          createdAt: created,
          updatedAt: updated,
          progress: [ProgressEntry(date: updated, page: 1250, fromPage: 0)],
        ),
      ],
    );
    final decoded = Book.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), original.toJson());
    expect(decoded.progressLabel(1250), '20:50');
    expect(decoded.sessions.single.daysTaken, isNull);
    expect(decoded.copyWith(notes: 'Changed').notes, 'Changed');
    expect(original.notes, 'N');
    expect(() => original.tags.add('x'), throwsUnsupportedError);
    expect(() => original.sessions.clear(), throwsUnsupportedError);
    expect(
      () => original.sessions.single.progress.clear(),
      throwsUnsupportedError,
    );
    expect(
      original.copyWith(coverImagePath: null, deletedAt: null).coverImagePath,
      isNull,
    );
    expect(
      original.sessions.single.copyWith(rating: null, endDate: null).isOpen,
      isTrue,
    );
  });
  test(
    'Day duration uses calendar dates and unknown dates never invent a duration',
    () {
      final session = ReadingSession(
        id: 's',
        startDate: DateTime(2026, 1, 1, 22),
        endDate: DateTime(2026, 1, 2),
      );
      expect(session.daysTaken, 2);
      expect(
        session.copyWith(precision: DatePrecision.unknown).daysTaken,
        isNull,
      );
    },
  );
}
