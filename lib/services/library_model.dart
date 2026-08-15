import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import 'storage_service.dart';

const _uuid = Uuid();

class LibraryModel extends ChangeNotifier {
  final StorageService _storage = StorageService();
  List<Book> _books = [];
  bool loading = true;

  List<Book> get books => List.unmodifiable(_books);

  Future<void> load() async {
    loading = true;
    notifyListeners();
    _books = await _storage.loadBooks();
    loading = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.saveBooks(_books);
    notifyListeners();
  }

  Future<void> addBook(Book book) async {
    _books.add(book);
    await _persist();
  }

  Future<void> updateBook(Book book) async {
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      _books[index] = book;
      await _persist();
    }
  }

  Future<void> deleteBook(String id) async {
    _books.removeWhere((b) => b.id == id);
    await _persist();
  }

  /// Begin a fresh read (first time) or a reread (book already finished
  /// at least once). Opens a new session with today as the start date.
  Future<void> startReading(Book book, {DateTime? startDate}) async {
    book.sessions.add(ReadingSession(
      id: _uuid.v4(),
      startDate: startDate ?? DateTime.now(),
    ));
    book.status = BookStatus.reading;
    await updateBook(book);
  }

  /// Close the currently-open session with an end date and optional rating.
  /// Finishing snaps the page count to the book's total (if known) — you
  /// read the whole thing, so the progress should show that.
  Future<void> finishReading(
    Book book, {
    DateTime? endDate,
    int? rating,
  }) async {
    final open = book.openSession;
    if (open == null) return;
    open.endDate = endDate ?? DateTime.now();
    open.rating = rating;
    if (book.totalPages != null) {
      open.currentPage = book.totalPages!;
    }
    book.status = BookStatus.read;
    await updateBook(book);
  }

  /// Set the current page directly (typed in, not stepped with +/-).
  Future<void> updatePage(Book book, int page) async {
    final open = book.openSession;
    if (open == null) return;
    final clamped = book.totalPages != null
        ? page.clamp(0, book.totalPages!)
        : (page < 0 ? 0 : page);
    open.currentPage = clamped;
    await updateBook(book);
  }

  Future<void> markDropped(Book book) async {
    // A dropped book keeps its open session as-is (no end date) so it's
    // clear the read was never completed.
    book.status = BookStatus.dropped;
    await updateBook(book);
  }

  /// Explicitly move a book back to "To Read" (e.g. from the edit screen).
  /// Resets progress on any open session to page 0.
  Future<void> setToRead(Book book) async {
    final open = book.openSession;
    if (open != null) open.currentPage = 0;
    book.status = BookStatus.toRead;
    await updateBook(book);
  }

  Future<void> importReplace(List<Book> imported) async {
    _books = imported;
    await _persist();
  }

  /// Convenience wrapper used by the UI: pick a file and replace the
  /// library in one step. Returns false if the user cancelled.
  Future<bool> importFromFile() async {
    final imported = await _storage.importBooks();
    if (imported == null) return false;
    await importReplace(imported);
    return true;
  }

  Future<String?> export() => _storage.exportBooks(_books);

  // --- Derived views, mirroring mangacompanion's tabs ---

  List<Book> get toRead =>
      _books.where((b) => b.status == BookStatus.toRead).toList();

  List<Book> get reading =>
      _books.where((b) => b.status == BookStatus.reading).toList();

  List<Book> get read => _books.where((b) => b.status == BookStatus.read).toList()
    ..sort((a, b) => (b.lastFinished ?? DateTime(0))
        .compareTo(a.lastFinished ?? DateTime(0)));

  List<Book> get dropped =>
      _books.where((b) => b.status == BookStatus.dropped).toList();

  // --- Stats, extended from mangacompanion's stats sheet ---

  int get totalBooksRead => read.length;

  int get totalSessionsCompleted =>
      _books.fold(0, (sum, b) => sum + b.timesRead);

  int get totalRereads => _books.fold(
      0, (sum, b) => sum + (b.timesRead > 1 ? b.timesRead - 1 : 0));

  /// Each completed read adds a book's full page count (so rereading a
  /// book three times adds its pages three times); a book you're
  /// currently partway through adds its live current page on top.
  /// Recomputed from _books every time, so deleting a book removes its
  /// pages from this total automatically.
  int get totalPagesRead {
    return _books.fold(0, (sum, b) {
      final completed = (b.totalPages ?? 0) * b.timesRead;
      final inProgress = b.openSession?.currentPage ?? 0;
      return sum + completed + inProgress;
    });
  }

  double? get averageRating {
    final rated = _books
        .expand((b) => b.sessions)
        .where((s) => s.rating != null)
        .map((s) => s.rating!)
        .toList();
    if (rated.isEmpty) return null;
    return rated.reduce((a, b) => a + b) / rated.length;
  }
}
