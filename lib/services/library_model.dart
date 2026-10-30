import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/book.dart';
import '../models/reading_session.dart';
import 'storage_service.dart';

enum ImportMode { merge, replace }

class ImportPreview {
  const ImportPreview(this.added, this.changed, this.removed, this.unchanged);
  final int added, changed, removed, unchanged;
}

class LibraryModel extends ChangeNotifier {
  LibraryModel({StorageService? storage})
    : storage = storage ?? StorageService();
  final StorageService storage;
  static const platform = MethodChannel('book_companion/device');
  List<Book> _books = [];
  bool loading = true, loadFailed = false, saving = false, autoSnapshots = true;
  String? saveError;
  Future<bool> Function()? _retry;
  bool get canRetry => _retry != null;
  Future<void> _queue = Future.value();
  List<Book> get books =>
      List.unmodifiable(_books.where((b) => b.deletedAt == null));
  List<Book> get trash =>
      List.unmodifiable(_books.where((b) => b.deletedAt != null));
  List<Book> get allBooks => List.unmodifiable(_books);
  Book current(Book book) =>
      _books.firstWhere((b) => b.id == book.id, orElse: () => book);
  Book? byId(String id) => books.where((b) => b.id == id).firstOrNull;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      _books = await storage.loadBooks();
      loadFailed = false;
    } catch (e) {
      loadFailed = true;
      await storage.logError('load', e);
    }
    loading = false;
    notifyListeners();
    await refreshWidget();
  }

  Future<bool> _mutate(
    Future<List<Book>> Function(List<Book>) transform, {
    bool recovery = false,
  }) {
    final result = _queue.then((_) async {
      if ((loadFailed && !recovery) || (saveError != null && _retry != null)) {
        return false;
      }
      saving = true;
      notifyListeners();
      try {
        var next = await transform(List.of(_books));
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        next = next
            .where((b) => b.deletedAt == null || b.deletedAt!.isAfter(cutoff))
            .toList();
        storage.validate(next);
        if (autoSnapshots && !loadFailed && _books.isNotEmpty) {
          await storage.snapshot(_books);
        }
        await storage.saveBooks(next);
        _books = next;
        loadFailed = false;
        saveError = null;
        _retry = null;
        await storage.cleanupCovers(next);
        await refreshWidget();
        return true;
      } catch (e) {
        saveError = e is LibraryFormatException
            ? e.message
            : 'Could not save. Your saved library is unchanged. Free some space and retry.';
        _retry = e is LibraryFormatException
            ? null
            : () => _mutate(transform, recovery: recovery);
        await storage.logError('save', e);
        return false;
      } finally {
        saving = false;
        notifyListeners();
      }
    });
    _queue = result.then<void>((_) {});
    return result;
  }

  Future<bool> retrySave() async {
    final retry = _retry;
    _retry = null;
    saveError = null;
    if (retry == null) return true;
    return await retry();
  }

  void discardFailedChange() {
    _retry = null;
    saveError = null;
    notifyListeners();
  }

  Future<bool> addBook(Book book) =>
      _mutate((books) async => [...books, await storage.prepareCover(book)]);
  Future<bool> updateBook(Book book) => _mutate((books) async {
    final prepared = await storage.prepareCover(book.copyWith());
    return books.map((b) => b.id == book.id ? prepared : b).toList();
  });
  Future<bool> _change(Book book, Book Function(Book) change) => _mutate(
    (books) async => books.map((b) => b.id == book.id ? change(b) : b).toList(),
  );
  Future<bool> deleteBook(String id) => bulk([id], deleted: true);
  Future<bool> restoreBook(String id) => _mutate(
    (books) async =>
        books.map((b) => b.id == id ? b.copyWith(deletedAt: null) : b).toList(),
  );
  Future<bool> bulk(
    Iterable<String> ids, {
    BookStatus? status,
    String? tag,
    bool deleted = false,
  }) => _mutate(
    (books) async => books.map((b) {
      if (!ids.contains(b.id)) return b;
      if (deleted) return b.copyWith(deletedAt: DateTime.now());
      var next = b;
      if (status != null) next = _withStatus(next, status);
      if (tag != null && tag.trim().isNotEmpty) {
        next = next.copyWith(tags: {...next.tags, tag.trim()}.toList());
      }
      return next;
    }).toList(),
  );
  Book _withStatus(Book b, BookStatus status) {
    final now = DateTime.now();
    if (status == BookStatus.toRead) {
      return b.copyWith(
        status: status,
        sessions: b.sessions.where((s) => !s.isOpen).toList(),
      );
    }
    if (status == BookStatus.reading && b.openSession == null) {
      return b.copyWith(
        status: status,
        sessions: [
          ...b.sessions,
          ReadingSession(id: const Uuid().v4(), startDate: now),
        ],
      );
    }
    if (status == BookStatus.read && b.openSession != null) {
      return _finish(b, now, b.openSession!.rating);
    }
    if (status == BookStatus.read && b.timesRead == 0) {
      return b.copyWith(
        status: status,
        sessions: [
          ReadingSession(
            id: const Uuid().v4(),
            startDate: now,
            endDate: now,
            currentPage: b.progressTotal ?? 0,
            precision: DatePrecision.unknown,
          ),
        ],
      );
    }
    return b.copyWith(status: status);
  }

  Future<bool> startReading(
    Book book, {
    DateTime? startDate,
    DatePrecision precision = DatePrecision.exact,
  }) => _change(book, (b) {
    if (b.openSession != null) return b.copyWith(status: BookStatus.reading);
    return b.copyWith(
      status: BookStatus.reading,
      sessions: [
        ...b.sessions,
        ReadingSession(
          id: const Uuid().v4(),
          startDate: startDate ?? DateTime.now(),
          precision: precision,
        ),
      ],
    );
  });
  Book _finish(Book b, DateTime end, int? rating) {
    final open = b.openSession;
    if (open == null) return b;
    final page = b.progressTotal ?? open.currentPage;
    return b.copyWith(
      status: BookStatus.read,
      sessions: b.sessions
          .map(
            (s) => s.id != open.id
                ? s
                : s.copyWith(
                    endDate: end,
                    rating: rating,
                    currentPage: page,
                    progress: [
                      ...s.progress,
                      if (page != s.currentPage)
                        ProgressEntry(
                          date: DateTime.now(),
                          page: page,
                          fromPage: s.currentPage,
                        ),
                    ],
                  ),
          )
          .toList(),
    );
  }

  Future<bool> finishReading(
    Book book, {
    DateTime? endDate,
    int? rating,
  }) async {
    final ok = await _change(
      book,
      (b) => _finish(b, endDate ?? DateTime.now(), rating),
    );
    if (ok) await HapticFeedback.lightImpact();
    return ok;
  }

  Future<bool> editSession(
    Book book,
    ReadingSession session, {
    DateTime? startDate,
    DateTime? endDate,
    required int? rating,
    DatePrecision? precision,
  }) async {
    final ok = await _change(
      book,
      (b) => b.copyWith(
        sessions: b.sessions
            .map(
              (s) => s.id != session.id
                  ? s
                  : s.copyWith(
                      startDate: startDate,
                      endDate: endDate ?? s.endDate,
                      rating: rating,
                      precision: precision,
                    ),
            )
            .toList(),
      ),
    );
    if (ok) await HapticFeedback.selectionClick();
    return ok;
  }

  Future<bool> updatePage(Book book, int page, {DateTime? date}) =>
      _change(book, (b) {
        final open = b.openSession;
        if (open == null || page == open.currentPage) return b;
        return b.copyWith(
          sessions: b.sessions
              .map(
                (s) => s.id != open.id
                    ? s
                    : s.copyWith(
                        currentPage: page,
                        progress: [
                          ...s.progress,
                          ProgressEntry(
                            date: date ?? DateTime.now(),
                            page: page,
                            fromPage: s.currentPage,
                          ),
                        ],
                      ),
              )
              .toList(),
        );
      });
  Future<bool> markDropped(Book book, {String? reason}) => _change(
    book,
    (b) => b.copyWith(status: BookStatus.dropped, dropReason: reason),
  );
  Future<bool> setToRead(Book book) =>
      _change(book, (b) => _withStatus(b, BookStatus.toRead));
  Future<bool> setStatus(Book book, BookStatus status) =>
      _change(book, (b) => _withStatus(b, status));
  Future<bool> addQuote(Book book, BookQuote quote) =>
      _change(book, (b) => b.copyWith(quotes: [...b.quotes, quote]));
  Future<bool> deleteQuote(Book book, String id) => _change(
    book,
    (b) => b.copyWith(quotes: b.quotes.where((q) => q.id != id).toList()),
  );

  ImportPreview preview(ImportData data, ImportMode mode) {
    final existing = {for (final b in _books) b.id: b};
    var added = 0, changed = 0, unchanged = 0;
    for (final b in data.books) {
      final old = existing[b.id];
      if (old == null) {
        added++;
      } else if (mode == ImportMode.replace ||
          b.updatedAt.isAfter(old.updatedAt)) {
        changed++;
      } else {
        unchanged++;
      }
    }
    final importedIds = data.books.map((b) => b.id).toSet();
    return ImportPreview(
      added,
      changed,
      mode == ImportMode.merge
          ? 0
          : _books.where((b) => !importedIds.contains(b.id)).length,
      unchanged,
    );
  }

  Future<bool> importData(ImportData data, ImportMode mode) => _mutate((
    books,
  ) async {
    // Forced snapshot also protects the unreadable original, byte-for-byte.
    if (loadFailed) {
      final original = await storage.file('books.json');
      if (await original.exists()) {
        await storage.atomicWrite(
          await storage.file(
            'snapshots/unreadable-${DateTime.now().microsecondsSinceEpoch}.json',
          ),
          await original.readAsBytes(),
        );
      }
    } else {
      await storage.snapshot(books, force: true);
    }
    final imported = await storage.materialize(data);
    if (mode == ImportMode.replace) return imported;
    final merged = {for (final b in books) b.id: b};
    for (final b in imported) {
      final old = merged[b.id];
      if (old == null || b.updatedAt.isAfter(old.updatedAt)) merged[b.id] = b;
    }
    return merged.values.toList();
  }, recovery: true);
  Future<bool> importReplace(List<Book> books) =>
      importData(ImportData(books), ImportMode.replace);
  Future<String?> export() => storage.exportBooks(_books);
  Future<void> refreshWidget({bool private = false}) async {
    try {
      final book = reading.firstOrNull;
      await platform.invokeMethod<void>('updateWidget', {
        'id': private ? '' : book?.id ?? '',
        'title': private ? 'Library locked' : book?.title ?? 'No book open',
        'progress': private || book == null
            ? ''
            : '${book.progressLabel(book.openSession?.currentPage ?? 0)} / ${book.progressTotal == null ? '?' : book.progressLabel(book.progressTotal!)}',
        'percent': private || book == null ? 0 : (book.progress * 100).round(),
      });
    } on MissingPluginException {
      /* Unit tests / non-Android hosts. */
    } catch (e) {
      await storage.logError('widget', e);
    }
  }

  String get diagnosticSummary => jsonEncode({
    'books': books.length,
    'trash': trash.length,
    'loadFailed': loadFailed,
    'saveFailed': saveError != null,
  });
  List<Book> get toRead =>
      books.where((b) => b.status == BookStatus.toRead).toList();
  List<Book> get reading =>
      books.where((b) => b.status == BookStatus.reading).toList();
  List<Book> get read =>
      books.where((b) => b.status == BookStatus.read).toList();
  List<Book> get dropped =>
      books.where((b) => b.status == BookStatus.dropped).toList();
  List<Book> get onHold =>
      books.where((b) => b.status == BookStatus.onHold).toList();
  int get totalBooksRead => books.where((b) => b.timesRead > 0).length;
  int get totalSessionsCompleted =>
      books.fold(0, (sum, b) => sum + b.timesRead);
  int get totalRereads =>
      books.fold(0, (sum, b) => sum + (b.timesRead > 1 ? b.timesRead - 1 : 0));
  int get totalPagesRead => books
      .where((b) => !b.isAudio)
      .fold(
        0,
        (sum, b) =>
            sum +
            b.sessions.fold(
              0,
              (total, s) =>
                  total +
                  (s.isOpen ? s.currentPage : b.totalPages ?? s.currentPage),
            ),
      );
  double? get averageRating {
    final ratings = books
        .expand((b) => b.sessions)
        .where((s) => s.rating != null)
        .map((s) => s.rating!)
        .toList();
    return ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;
  }
}
