import 'package:book_companion/services/library_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('The expected saved state did not arrive.');
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
      maxScrolls: 40,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> exerciseReadingFlow(
  WidgetTester tester,
  LibraryModel library,
) async {
  await tester.tap(find.byKey(const ValueKey('add-book')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('field-Title')),
    'Emulator Book',
  );
  await tester.enterText(
    find.byKey(const ValueKey('field-Author')),
    'Test Reader',
  );
  await tester.enterText(
    find.byKey(const ValueKey('field-Total pages')),
    '120',
  );
  final save = find.byKey(const ValueKey('save-book'));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 500));
  await reveal(tester, save);
  await tester.pump(const Duration(milliseconds: 300));
  await reveal(tester, save);
  await tester.tap(save);
  await tester.pumpAndSettle();
  await waitFor(tester, () => library.books.isNotEmpty);
  expect(library.books.single.title, 'Emulator Book');
  await tester.tap(find.text('to read'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Emulator Book'));
  await tester.pumpAndSettle();
  await reveal(tester, find.text('Start reading'));
  await tester.tap(find.text('Start reading'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await waitFor(tester, () => library.reading.isNotEmpty);
  expect(library.reading.length, 1);
  await reveal(tester, find.text('Set page'));
  await tester.tap(find.text('Set page'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('progress-input')), '121');
  await tester.tap(find.text('Save page'));
  await tester.pumpAndSettle();
  expect(find.text('This book ends at 120.'), findsOneWidget);
  await tester.enterText(find.byKey(const ValueKey('progress-input')), '42');
  await tester.tap(find.text('Save page'));
  await tester.pumpAndSettle();
  await waitFor(
    tester,
    () => library.reading.single.openSession!.currentPage == 42,
  );
  expect(library.reading.single.openSession!.currentPage, 42);
  expect(library.reading.single.openSession!.progress.length, 1);
  await reveal(tester, find.text('Finish read'));
  await tester.tap(find.text('Finish read'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('4 out of 5'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save read'));
  await tester.pumpAndSettle();
  await waitFor(tester, () => library.read.isNotEmpty);
  expect(library.read.single.timesRead, 1);
  expect(library.read.single.averageRating, 4);
  expect(library.read.single.sessions.single.currentPage, 120);
  expect(tester.takeException(), isNull);
}
