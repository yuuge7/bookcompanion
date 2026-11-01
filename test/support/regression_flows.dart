import 'package:book_companion/models/book.dart';
import 'package:book_companion/models/reading_session.dart';
import 'package:book_companion/services/library_model.dart';
import 'package:book_companion/services/library_query.dart';
import 'package:book_companion/services/reading_stats.dart';
import 'package:book_companion/widgets/book_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reading_flow.dart';

List<Book> queryBooks() => [
  for (final (i, title, author, rating, progress, day, format) in [
    (0, 'Alpha', 'Z Author', 5, 20, 1, BookFormat.ebook),
    (1, 'Zulu', 'A Author', 1, 80, 3, BookFormat.hardcover),
    (2, 'Middle', 'M Author', 3, 40, 2, BookFormat.paperback),
  ])
    Book(
      id: 'query-$i',
      title: title,
      author: author,
      status: BookStatus.reading,
      totalPages: 100,
      tags: i == 0 ? ['fiction'] : ['memoir'],
      series: i == 0 ? 'Series A' : '',
      createdAt: DateTime(2023 + i),
      updatedAt: DateTime(2026, 2, 9 - i),
      sessions: [
        ReadingSession(
          id: 'closed-$i',
          startDate: DateTime(2024 + i.clamp(0, 1)),
          endDate: DateTime(2024 + i.clamp(0, 1), 2),
          rating: rating,
          format: format,
          totalLength: 100,
          currentPage: 100,
        ),
        ReadingSession(
          id: 'open-$i',
          startDate: DateTime(2026, 1, day),
          currentPage: progress,
        ),
      ],
    ),
];

Book rereadBook() => Book(
  id: 'reread',
  title: 'Reread Book',
  status: BookStatus.read,
  format: BookFormat.ebook,
  totalPages: 200,
  totalMinutes: 120,
  sessions: [
    ReadingSession(
      id: 'first-ebook',
      startDate: DateTime(2024),
      endDate: DateTime(2024, 2),
      format: BookFormat.ebook,
      totalLength: 200,
      currentPage: 200,
      precision: DatePrecision.unknown,
    ),
  ],
);

Future<void> chooseDrop(WidgetTester tester, String label, String value) async {
  final field = find.byWidgetPredicate(
    (w) => w is DropdownButtonFormField && w.decoration.labelText == label,
  );
  await reveal(tester, field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('library-filters')));
  await tester.pumpAndSettle();
}

List<String> visibleTitles(WidgetTester tester) => tester
    .widgetList<BookRow>(find.byType(BookRow))
    .map((w) => w.book.title)
    .toList();

Future<void> exerciseQueryControls(WidgetTester tester) async {
  expect(visibleTitles(tester), ['Alpha', 'Middle', 'Zulu']);
  for (final (sort, expected) in [
    (LibrarySort.author, ['Zulu', 'Middle', 'Alpha']),
    (LibrarySort.dateAdded, ['Middle', 'Zulu', 'Alpha']),
    (LibrarySort.lastRead, ['Zulu', 'Middle', 'Alpha']),
    (LibrarySort.lastEdited, ['Alpha', 'Zulu', 'Middle']),
    (LibrarySort.rating, ['Alpha', 'Middle', 'Zulu']),
    (LibrarySort.progress, ['Zulu', 'Middle', 'Alpha']),
    (LibrarySort.title, ['Alpha', 'Middle', 'Zulu']),
  ]) {
    await openFilters(tester);
    await chooseDrop(tester, 'Sort by', sort.label);
    await tester.tap(find.byKey(const ValueKey('apply-filters')));
    await tester.pumpAndSettle();
    expect(visibleTitles(tester), expected, reason: sort.label);
    await openFilters(tester);
    await tester.tap(
      find.text(
        (sort.defaultDescending ? sort.ascendingLabel : sort.descendingLabel)
            .toLowerCase(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-filters')));
    await tester.pumpAndSettle();
    expect(
      visibleTitles(tester),
      expected.reversed.toList(),
      reason: '${sort.label} reversed',
    );
  }
  await openFilters(tester);
  await chooseDrop(tester, 'Sort by', 'Author');
  await tester.tap(find.byTooltip('Cancel filters'));
  await tester.pumpAndSettle();
  expect(visibleTitles(tester), ['Zulu', 'Middle', 'Alpha']);
  await openFilters(tester);
  await chooseDrop(tester, 'Tag / genre', 'fiction');
  await chooseDrop(tester, 'Format of any read', 'Ebook');
  await chooseDrop(tester, 'Year finished', '2024');
  await chooseDrop(tester, 'Rating (rounded average)', '5 stars');
  await chooseDrop(tester, 'Series', 'Series A');
  expect(find.text('Show 1 book'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('apply-filters')));
  await tester.pumpAndSettle();
  expect(visibleTitles(tester), ['Alpha']);
  await openFilters(tester);
  await chooseDrop(tester, 'Format of any read', 'Audiobook');
  expect(find.text('Show 0 books'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('apply-filters')));
  await tester.pumpAndSettle();
  expect(find.text('No matching books on this shelf'), findsOneWidget);
  await openFilters(tester);
  await tester.tap(find.text('Clear filters').last);
  await tester.pumpAndSettle();
  expect(find.text('Show 3 books'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('apply-filters')));
  await tester.pumpAndSettle();
  expect(visibleTitles(tester), ['Zulu', 'Middle', 'Alpha']);
  await openFilters(tester);
  await chooseDrop(tester, 'Format of any read', 'Hardcover');
  await chooseDrop(tester, 'Format of any read', 'All');
  expect(find.text('Show 3 books'), findsOneWidget);
  await tester.tap(find.byTooltip('Cancel filters'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> exerciseReadFormats(
  WidgetTester tester,
  LibraryModel library,
) async {
  await tester.tap(find.text('read'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reread Book'));
  await tester.pumpAndSettle();
  await reveal(tester, find.text('Start a reread'));
  await tester.tap(find.text('Start a reread'));
  await tester.pumpAndSettle();
  await chooseDrop(tester, 'Format for this read', 'Paperback');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await waitFor(tester, () => library.byId('reread')!.openSession != null);
  expect(library.byId('reread')!.sessions.first.format, BookFormat.ebook);
  expect(library.byId('reread')!.openSession!.format, BookFormat.paperback);
  await reveal(tester, find.text('Finish read'));
  await tester.tap(find.text('Finish read'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save read'));
  await tester.pumpAndSettle();
  await waitFor(tester, () => library.byId('reread')!.timesRead == 2);
  await reveal(tester, find.byKey(const ValueKey('read-first-ebook')));
  await tester.tap(find.byKey(const ValueKey('read-first-ebook')));
  await tester.pumpAndSettle();
  await chooseDrop(tester, 'Format for this read', 'Hardcover');
  await tester.tap(find.text('Save read'));
  await tester.pumpAndSettle();
  await waitFor(
    tester,
    () => library.byId('reread')!.sessions.first.format == BookFormat.hardcover,
  );
  await reveal(tester, find.text('Start a reread'));
  await tester.tap(find.text('Start a reread'));
  await tester.pumpAndSettle();
  await chooseDrop(tester, 'Format for this read', 'Audiobook');
  await tester.enterText(find.byKey(const ValueKey('read-length')), '1:30');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await waitFor(tester, () => library.byId('reread')!.openSession != null);
  await reveal(tester, find.text('Set time'));
  await tester.tap(find.text('Set time'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('progress-input')), '1:00');
  await tester.tap(find.text('Save time'));
  await tester.pumpAndSettle();
  await waitFor(
    tester,
    () => library.byId('reread')!.openSession!.currentPage == 60,
  );
  await reveal(tester, find.text('Finish read'));
  await tester.tap(find.text('Finish read'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save read'));
  await tester.pumpAndSettle();
  await waitFor(tester, () => library.byId('reread')!.timesRead == 3);
  final book = library.byId('reread')!;
  expect(book.sessions.map((s) => s.format), [
    BookFormat.hardcover,
    BookFormat.paperback,
    BookFormat.audiobook,
  ]);
  expect(book.sessions.map((s) => s.totalLength), [200, 200, 90]);
  final stats = ReadingStats([book]);
  expect(stats.pages, 400);
  expect(stats.minutes, 90);
  expect(stats.formats, {'Hardcover': 1, 'Paperback': 1, 'Audiobook': 1});
  expect(library.totalPagesRead, 400);
  expect(tester.takeException(), isNull);
}

List<Book> reviewBooks() => [
  for (var i = 0; i < 8; i++)
    Book(
      id: 'review-$i',
      title: 'Review $i',
      author: 'Author $i',
      tags: ['Genre $i'],
      totalPages: 100,
      sessions: [
        ReadingSession(
          id: 'review-read-$i',
          startDate: DateTime(DateTime.now().year, 1),
          endDate: DateTime(DateTime.now().year, 2),
          currentPage: 100,
        ),
      ],
    ),
];

Future<void> exerciseYearReview(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Stats'));
  await tester.pumpAndSettle();
  await reveal(tester, find.text('Year in Review'));
  await tester.tap(find.text('Year in Review'));
  await tester.pumpAndSettle();
  final save = find.byKey(const ValueKey('save-year-review'));
  expect(save.hitTestable(), findsOneWidget);
  final scroll = find.byKey(const ValueKey('year-review-scroll'));
  for (
    var i = 0;
    i < 12 &&
        find.text('Read. Remember. Repeat.').hitTestable().evaluate().isEmpty;
    i++
  ) {
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  expect(find.text('Read. Remember. Repeat.').hitTestable(), findsOneWidget);
  expect(save.hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
  await tester.tap(save);
  await tester.pumpAndSettle();
}
