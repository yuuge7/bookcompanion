import 'package:book_companion/models/book.dart';
import 'package:book_companion/models/reading_session.dart';
import 'package:book_companion/services/library_model.dart';
import 'package:book_companion/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStorage storage;
  late LibraryModel model;
  setUp(() async {
    storage = MemoryStorage();
    model = LibraryModel(storage: storage);
    await model.load();
  });
  tearDown(() => model.dispose());
  test(
    'Start, progress, hold, resume, finish, reread, rate, drop and to-read preserve history',
    () async {
      final book = Book(id: 'b', title: 'Book', totalPages: 100);
      expect(await model.addBook(book), isTrue);
      await model.startReading(book, startDate: DateTime(2026, 1, 1));
      await model.updatePage(book, 30);
      await model.setStatus(book, BookStatus.onHold);
      expect(model.onHold.single.openSession!.currentPage, 30);
      await model.startReading(book);
      expect(model.reading.single.sessions.length, 1);
      await model.finishReading(book, endDate: DateTime(2026, 1, 2), rating: 4);
      expect(model.totalBooksRead, 1);
      expect(model.totalPagesRead, 100);
      await model.startReading(book);
      expect(model.totalBooksRead, 1);
      await model.updatePage(book, 25);
      expect(model.totalPagesRead, 125);
      await model.finishReading(book, rating: 2);
      expect(model.totalRereads, 1);
      expect(model.totalPagesRead, 200);
      expect(model.averageRating, 3);
      final session = model.books.single.sessions.first;
      await model.editSession(
        book,
        session,
        rating: null,
        precision: DatePrecision.unknown,
      );
      expect(model.averageRating, 2);
      await model.startReading(book);
      await model.markDropped(book, reason: 'Later');
      expect(model.dropped.single.dropReason, 'Later');
      await model.setToRead(book);
      expect(model.toRead.single.openSession, isNull);
      expect(model.books.single.timesRead, 2);
    },
  );
  test(
    'Failed save leaves disk and memory unchanged; retry commits the pending change',
    () async {
      final b = Book(id: 'b', title: 'Original');
      await model.addBook(b);
      storage.failSave = true;
      expect(await model.updateBook(b.copyWith(title: 'Edited')), isFalse);
      expect(model.books.single.title, 'Original');
      expect(storage.saved.single.title, 'Original');
      expect(model.saveError, isNotNull);
      storage.failSave = false;
      expect(await model.retrySave(), isTrue);
      expect(model.books.single.title, 'Edited');
      expect(model.saveError, isNull);
    },
  );
  test('Concurrent page changes serialize against current data', () async {
    final b = Book(id: 'b', title: 'B', totalPages: 100);
    await model.addBook(b);
    await model.startReading(b);
    await Future.wait([
      model.updatePage(b, 10),
      model.updatePage(b, 20),
      model.updatePage(b, 30),
    ]);
    expect(model.books.single.openSession!.currentPage, 30);
    expect(model.books.single.openSession!.progress.map((p) => p.page), [
      10,
      20,
      30,
    ]);
    expect(model.books.single.openSession!.progress.map((p) => p.fromPage), [
      0,
      10,
      20,
    ]);
  });
  test(
    'Invalid progress never commits; valid change can be retried after discard',
    () async {
      final b = Book(id: 'b', title: 'B', totalPages: 100);
      await model.addBook(b);
      await model.startReading(b);
      expect(await model.updatePage(b, 101), isFalse);
      expect(model.books.single.openSession!.currentPage, 0);
      model.discardFailedChange();
      expect(await model.updatePage(b, 100), isTrue);
    },
  );
  test(
    'Merge preview, newer-wins, tie retention and replacement snapshots',
    () async {
      final old = DateTime(2025), recent = DateTime(2026);
      await model.addBook(
        Book(id: 'b', title: 'Local', createdAt: old, updatedAt: recent),
      );
      final data = ImportData([
        Book(id: 'b', title: 'Old import', createdAt: old, updatedAt: old),
        Book(id: 'new', title: 'New'),
      ]);
      final preview = model.preview(data, ImportMode.merge);
      expect(preview.added, 1);
      expect(preview.changed, 0);
      expect(preview.unchanged, 1);
      expect(preview.removed, 0);
      await model.importData(data, ImportMode.merge);
      expect(model.byId('b')!.title, 'Local');
      final update = ImportData([
        model.byId('b')!.copyWith(title: 'Incoming', updatedAt: DateTime(2027)),
      ]);
      expect(model.preview(update, ImportMode.replace).removed, 1);
      await model.importData(update, ImportMode.replace);
      expect(model.books.single.title, 'Incoming');
      expect(storage.snapshotsTaken, greaterThan(0));
    },
  );
  test(
    'Trash retains history, bulk status and tags work, restore revives the book',
    () async {
      await model.addBook(Book(id: 'a', title: 'A'));
      await model.addBook(Book(id: 'b', title: 'B'));
      await model.bulk(['a', 'b'], status: BookStatus.reading, tag: 'fiction');
      expect(model.reading.length, 2);
      expect(model.books.every((b) => b.tags.contains('fiction')), isTrue);
      await model.bulk(['a', 'b'], deleted: true);
      expect(model.books, isEmpty);
      expect(model.trash.length, 2);
      await model.restoreBook('a');
      expect(model.books.single.id, 'a');
      expect(model.books.single.sessions.length, 1);
    },
  );
  test(
    'Unreadable libraries reject writes until an explicitly reviewed import',
    () async {
      storage.failLoad = true;
      await model.load();
      expect(model.loadFailed, isTrue);
      expect(await model.addBook(Book(id: 'a', title: 'A')), isFalse);
      storage.failLoad = false;
    },
  );
  test('Audio totals do not inflate page totals', () async {
    final b = Book(
      id: 'a',
      title: 'Audio',
      format: BookFormat.audiobook,
      totalMinutes: 120,
    );
    await model.addBook(b);
    await model.startReading(b);
    await model.updatePage(b, 60);
    await model.finishReading(b);
    expect(model.totalPagesRead, 0);
    expect(model.totalSessionsCompleted, 1);
    expect(model.books.single.sessions.single.currentPage, 120);
  });
}
