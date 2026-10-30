import 'package:book_companion/main.dart';
import 'package:book_companion/models/book.dart';
import 'package:book_companion/services/library_model.dart';
import 'package:book_companion/services/storage_service.dart';
import 'package:book_companion/widgets/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/reading_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LibraryModel.platform, (_) async => null);
  });
  testWidgets('All five rating controls remain usable in a narrow dialog', (
    tester,
  ) async {
    int? rating;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 232,
              child: StarRating(value: rating, onChanged: (v) => rating = v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('5 out of 5'));
    expect(rating, 5);
  });
  testWidgets('Add → start → validate page → log page → finish → rate', (
    tester,
  ) async {
    final storage = MemoryStorage(),
        settings = TestSettings(storage: MemoryStorage());
    final library = LibraryModel(storage: storage);
    await library.load();
    await tester.pumpWidget(
      BookCompanionApp(library: library, settings: settings),
    );
    await tester.pumpAndSettle();
    await exerciseReadingFlow(tester, library);
  });
  testWidgets(
    'Large text on narrow screen keeps library, form, settings and stats usable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final library = LibraryModel(storage: MemoryStorage());
      await library.load();
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: TestSettings()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Stats'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-book')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Lock covers the navigation stack and blocks detail after backgrounding',
    (tester) async {
      final storage = MemoryStorage()
        ..saved = [
          Book(id: 'secret', title: 'Secret title', status: BookStatus.reading),
        ];
      final library = LibraryModel(storage: storage);
      await library.load();
      final settings = TestSettings();
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: settings),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Secret title'));
      await tester.pumpAndSettle();
      settings.appLock = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Your library is locked'), findsOneWidget);
      expect(find.text('Secret title'), findsNothing);
      await tester.tap(find.text('Unlock library'));
      await tester.pumpAndSettle();
      expect(find.text('Secret title'), findsOneWidget);
    },
  );
  testWidgets(
    'Import preview can cancel a replacement, then merge newer records',
    (tester) async {
      final storage = MemoryStorage()
        ..saved = [Book(id: 'local', title: 'Local')]
        ..pickedImport = ImportData([Book(id: 'incoming', title: 'Incoming')]);
      final library = LibraryModel(storage: storage);
      await library.load();
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: TestSettings()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Backups, import & export'));
      await tester.tap(find.text('Backups, import & export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import / restore file'));
      await tester.pumpAndSettle();
      expect(find.text('Review import'), findsOneWidget);
      await tester.tap(find.text('replace'));
      await tester.pumpAndSettle();
      expect(
        find.text('Replace your 1 books with 1 from this file?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(library.books.single.id, 'local');
      expect(storage.snapshotsTaken, 0);
      await tester.tap(find.text('Import / restore file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Merge library'));
      await tester.pumpAndSettle();
      expect(library.books.length, 2);
      expect(storage.snapshotsTaken, greaterThan(0));
    },
  );
  testWidgets(
    'Bulk actions and deletion undo are reachable from library rows',
    (tester) async {
      final storage = MemoryStorage()
        ..saved = [Book(id: 'a', title: 'Alpha', status: BookStatus.reading)];
      final library = LibraryModel(storage: storage);
      await library.load();
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: TestSettings()),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bulk actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to On Hold'));
      await tester.pumpAndSettle();
      expect(library.onHold.length, 1);
      await tester.tap(find.text('on hold'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete book'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete book'));
      await tester.pumpAndSettle();
      expect(library.books, isEmpty);
      expect(library.trash.length, 1);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(library.books.single.id, 'a');
    },
  );
}
