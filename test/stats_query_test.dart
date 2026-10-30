import 'package:book_companion/models/book.dart';
import 'package:book_companion/models/reading_session.dart';
import 'package:book_companion/services/library_query.dart';
import 'package:book_companion/services/reading_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Year stats, unknown dates, rereads, ratings and audio totals are consistent',
    () {
      final books = [
        Book(
          id: 'b',
          title: 'B',
          author: 'Author',
          tags: ['fiction'],
          totalPages: 100,
          sessions: [
            ReadingSession(
              id: '1',
              startDate: DateTime(2024),
              endDate: DateTime(2024, 2),
              currentPage: 100,
              rating: 4,
            ),
            ReadingSession(
              id: '2',
              startDate: DateTime(2025),
              endDate: DateTime(2025, 3),
              currentPage: 100,
              rating: 2,
            ),
            ReadingSession(
              id: '3',
              startDate: DateTime(2026),
              endDate: DateTime(2026, 4),
              currentPage: 100,
              precision: DatePrecision.unknown,
            ),
          ],
        ),
        Book(
          id: 'a',
          title: 'Audio',
          format: BookFormat.audiobook,
          totalMinutes: 120,
          sessions: [
            ReadingSession(
              id: '4',
              startDate: DateTime(2025),
              endDate: DateTime(2025, 2),
              currentPage: 120,
            ),
          ],
        ),
      ];
      final stats = ReadingStats(books, year: 2025);
      expect(stats.booksRead, 2);
      expect(stats.completedReads, 2);
      expect(stats.rereads, 1);
      expect(stats.pages, 100);
      expect(stats.minutes, 120);
      expect(stats.averageRating, 2);
      expect(stats.booksByMonth[1], 1);
      expect(stats.booksByMonth[2], 1);
      expect(stats.authors, {'Author': 1});
      expect(stats.tags, {'fiction': 1});
      expect(ReadingStats(books, year: 2026).completedReads, 0);
      expect(ReadingStats(books).pages, 300);
      expect(ReadingStats(books).averageRating, 3);
    },
  );
  test('Progress corrections do not inflate pages, pace or streaks', () {
    final book = Book(
      id: 'b',
      title: 'B',
      totalPages: 100,
      sessions: [
        ReadingSession(
          id: 's',
          startDate: DateTime(2026, 1, 1),
          currentPage: 50,
          progress: [
            ProgressEntry(date: DateTime(2026, 1, 1), page: 20, fromPage: 0),
            ProgressEntry(date: DateTime(2026, 1, 2), page: 30, fromPage: 20),
            ProgressEntry(
              date: DateTime(2026, 1, 2, 15),
              page: 10,
              fromPage: 30,
            ),
            ProgressEntry(date: DateTime(2026, 1, 3), page: 30, fromPage: 10),
            ProgressEntry(date: DateTime(2026, 1, 4), page: 50, fromPage: 30),
          ],
        ),
      ],
    );
    final stats = ReadingStats([book], year: 2026, today: DateTime(2026, 1, 4));
    expect(stats.pages, 50);
    expect(stats.activeDays.length, 3);
    expect(stats.longestStreak, 2);
    expect(stats.currentStreak, 1);
    expect(stats.pagesByMonth[0], 50);
    expect(stats.pagesPerActiveDay, closeTo(50 / 3, .001));
    expect(ReadingStats.pace(book, today: DateTime(2026, 1, 4)), 12.5);
    expect(
      ReadingStats.predictedFinish(book, today: DateTime(2026, 1, 4)),
      DateTime(2026, 1, 8),
    );
  });
  test(
    'Old page baseline is not invented as new activity in the current year',
    () {
      final book = Book(
        id: 'b',
        title: 'B',
        sessions: [
          ReadingSession(
            id: 's',
            startDate: DateTime(2025),
            currentPage: 50,
            progress: [
              ProgressEntry(date: DateTime(2026), page: 50, fromPage: 40),
            ],
          ),
        ],
      );
      expect(ReadingStats([book], year: 2026).pages, 10);
      expect(ReadingStats([book]).pages, 50);
    },
  );
  test(
    'Search folds accents, accepts small typos, and searches every promised field',
    () {
      final book = Book(
        id: 'b',
        title: 'Élan',
        author: 'García',
        notes: 'Rainforest',
        series: 'Chronicles',
        tags: ['Fantasy'],
        quotes: [const BookQuote(id: 'q', text: 'Remember the future')],
      );
      for (final q in [
        'elan',
        'garcia',
        'raiforest',
        'chronciles',
        'fantasy',
        'future',
        'remember garcia',
      ]) {
        expect(matchesBook(book, q), isTrue, reason: q);
      }
      expect(matchesBook(book, 'completely unrelated'), isFalse);
    },
  );
  test('All sorting and filtering choices operate together', () {
    final books = [
      Book(
        id: 'b',
        title: 'Zulu',
        author: 'A',
        createdAt: DateTime(2020),
        tags: ['fiction'],
        series: 'S',
        format: BookFormat.ebook,
        sessions: [
          ReadingSession(
            id: 's',
            startDate: DateTime(2025),
            endDate: DateTime(2025, 2),
            rating: 5,
          ),
        ],
      ),
      Book(id: 'a', title: 'Alpha', author: 'Z', createdAt: DateTime(2026)),
    ];
    final query = LibraryQuery()
      ..sort = LibrarySort.title
      ..descending = false;
    expect(query.apply(books).first.id, 'a');
    query.sort = LibrarySort.author;
    expect(query.apply(books).first.id, 'b');
    query.sort = LibrarySort.dateAdded;
    expect(query.apply(books).first.id, 'b');
    query.sort = LibrarySort.rating;
    expect(query.apply(books).last.id, 'b');
    query
      ..tag = 'fiction'
      ..series = 'S'
      ..format = BookFormat.ebook
      ..finishedYear = 2025
      ..rating = 5;
    expect(query.apply(books).single.id, 'b');
    query.finishedYear = 2024;
    expect(query.apply(books), isEmpty);
  });
}
