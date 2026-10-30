import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:book_companion/models/book.dart';
import 'package:book_companion/models/reading_session.dart';
import 'package:book_companion/services/export_service.dart';
import 'package:book_companion/services/storage_service.dart';
import 'package:book_companion/services/theme_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late StorageService storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('book-companion-test-');
    storage = StorageService(directory: directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  for (final version in ['v1.0', 'v1.1', 'v1.2', 'v1.3', 'v1.4', 'v1.5']) {
    test(
      '$version export remains readable and retains ratings and progress',
      () async {
        final books = storage.parseJson(
          await File('test/fixtures/$version.json').readAsString(),
        );
        expect(books.length, 2);
        expect(books.first.timesRead, 1);
        expect(books.first.averageRating, 4);
        expect(books.last.openSession!.currentPage, 42);
        expect(books.first.sessions.first.precision, DatePrecision.exact);
        await storage.saveBooks(books);
        expect(
          (await storage.loadBooks()).map((b) => b.toJson()),
          books.map((b) => b.toJson()),
        );
      },
    );
  }
  test(
    'Atomic writes replace complete data and ignore interrupted .tmp files',
    () async {
      await storage.saveBooks([Book(id: 'a', title: 'Before')]);
      await (await storage.file('books.json.tmp')).writeAsString('{partial');
      expect((await storage.loadBooks()).single.title, 'Before');
      await storage.saveBooks([Book(id: 'a', title: 'After')]);
      expect((await storage.loadBooks()).single.title, 'After');
      expect(await (await storage.file('books.json.tmp')).exists(), isFalse);
      final envelope =
          jsonDecode(await (await storage.file('books.json')).readAsString())
              as Map<String, dynamic>;
      expect(envelope['schemaVersion'], 2);
      expect(envelope['app'], 'book_companion');
    },
  );
  test(
    'Unreadable, empty and future-version libraries are rejected without overwriting',
    () async {
      final file = await storage.file('books.json');
      for (final raw in [
        '',
        '{bad',
        '{"app":"book_companion","schemaVersion":99,"books":[]}',
      ]) {
        await file.writeAsString(raw);
        await expectLater(
          storage.loadBooks(),
          throwsA(isA<LibraryFormatException>()),
        );
        expect(await file.readAsString(), raw);
      }
    },
  );
  test(
    'Strict validation identifies duplicate IDs, bad dates, ratings and page bounds',
    () {
      final b = Book(id: 'b', title: 'Example', totalPages: 100);
      final bad = [
        [b, b],
        [b.copyWith(title: '')],
        [b.copyWith(totalPages: -1)],
        [
          b.copyWith(
            sessions: [
              ReadingSession(
                id: 's',
                startDate: DateTime(2026, 2),
                endDate: DateTime(2026, 1),
              ),
            ],
          ),
        ],
        [
          b.copyWith(
            sessions: [
              ReadingSession(id: 's', startDate: DateTime(2026), rating: 6),
            ],
          ),
        ],
        [
          b.copyWith(
            sessions: [
              ReadingSession(
                id: 's',
                startDate: DateTime(2026),
                currentPage: 101,
              ),
            ],
          ),
        ],
      ];
      for (final books in bad) {
        expect(
          () => storage.parseJson(
            jsonEncode(books.map((b) => b.toJson()).toList()),
          ),
          throwsA(isA<LibraryFormatException>()),
        );
      }
      try {
        storage.validate(bad.first);
      } on LibraryFormatException catch (e) {
        expect(e.message, contains('Book 2 (Example)'));
      }
    },
  );
  test(
    'Cover copied to durable storage, EXIF removed, and backup restores on another device',
    () async {
      final image = img.Image(width: 100, height: 150);
      image.exif.imageIfd.make = 'Camera';
      image.exif.gpsIfd.gpsLatitude = 44.4;
      final original = File('${directory.path}/picked.jpg');
      await original.writeAsBytes(img.encodeJpg(image));
      final book = await storage.prepareCover(
        Book(id: 'b', title: 'Book', coverImagePath: original.path),
      );
      final decoded = img.decodeJpg(
        await File(book.coverImagePath!).readAsBytes(),
      )!;
      expect(decoded.exif.imageIfd.make, isNull);
      expect(decoded.exif.gpsIfd.gpsLatitude, isNull);
      await original.delete();
      expect(await File(book.coverImagePath!).exists(), isTrue);
      final backup = await storage.backupBytes([book]);
      final imported = storage.decodeBackup(backup);
      expect(imported.covers.length, 1);
      expect(imported.books.single.coverImagePath, startsWith('covers/'));
      final otherDirectory = Directory('${directory.path}/other-device');
      final other = StorageService(directory: otherDirectory);
      final restored = await other.materialize(imported);
      await other.saveBooks(restored);
      expect(restored.single.coverImagePath, startsWith(otherDirectory.path));
      expect(await File(restored.single.coverImagePath!).exists(), isTrue);
      expect((await other.loadBooks()).single.title, 'Book');
    },
  );
  test('Legacy cache covers migrate before cache can be cleared', () async {
    final picked = File('${directory.path}/cache.png');
    await picked.writeAsBytes(img.encodePng(img.Image(width: 10, height: 15)));
    final b = Book(id: 'b', title: 'Legacy', coverImagePath: picked.path);
    await (await storage.file(
      'books.json',
    )).writeAsString(jsonEncode([b.toJson()]));
    final loaded = await storage.loadBooks();
    await picked.delete();
    expect(await File(loaded.single.coverImagePath!).exists(), isTrue);
    expect(
      (await storage.loadBooks()).single.coverImagePath,
      loaded.single.coverImagePath,
    );
  });
  test(
    'Checksum tampering, unsafe paths and missing files never import',
    () async {
      final bytes = await storage.backupBytes([Book(id: 'a', title: 'Safe')]);
      final archive = ZipDecoder().decodeBytes(bytes);
      final changed = Archive();
      for (final entry in archive.files) {
        final contents = entry.name == 'library.json'
            ? utf8.encode('[]')
            : entry.content;
        changed.addFile(ArchiveFile(entry.name, contents.length, contents));
      }
      expect(
        () => storage.decodeBackup(
          Uint8List.fromList(ZipEncoder().encode(changed)),
        ),
        throwsA(isA<LibraryFormatException>()),
      );
      changed.addFile(ArchiveFile('../outside', 1, [0]));
      expect(
        () => storage.decodeBackup(
          Uint8List.fromList(ZipEncoder().encode(changed)),
        ),
        throwsA(isA<LibraryFormatException>()),
      );
      expect(
        () => storage.decodeBackup(Uint8List.fromList([80, 75, 1, 2, 3])),
        throwsA(isA<LibraryFormatException>()),
      );
    },
  );
  test('Automatic snapshots are self-contained and bounded', () async {
    for (var i = 0; i < 12; i++) {
      await storage.snapshot([
        Book(id: 'b', title: 'Snapshot $i'),
      ], force: true);
    }
    final snapshots = await storage.snapshots();
    expect(snapshots.length, 10);
    expect(
      storage
          .decodeBackup(await snapshots.first.readAsBytes())
          .books
          .single
          .title,
      'Snapshot 11',
    );
  });
  test(
    'Theme and reading preferences survive a fresh settings instance',
    () async {
      final prefs = ThemeNotifier(storage: storage);
      await prefs.load();
      await prefs.update({
        'theme': 'dark',
        'defaultPrecision': 'approximate',
        'firstDayOfWeek': 0,
        'goalYear': 2027,
        'goalTarget': 24,
        'goalUnit': 'books',
      });
      final next = ThemeNotifier(storage: storage);
      await next.load();
      expect(next.mode.name, 'dark');
      expect(next.defaultPrecision, DatePrecision.approximate);
      expect(next.firstDayOfWeek, 0);
      expect(next.goalTarget, 24);
      expect(next.goalYear, 2027);
      prefs.dispose();
      next.dispose();
    },
  );
  test(
    'Goodreads import understands quoted commas and missing historic dates',
    () {
      const input =
          'Book Id,Title,Author,Exclusive Shelf,Number of Pages,My Rating,Date Read,Date Added\n42,"A, B",Writer,read,100,4,,2020/01/01\n';
      final books = storage.parseGoodreads(input);
      expect(books.single.title, 'A, B');
      expect(books.single.averageRating, 4);
      expect(books.single.sessions.single.precision, DatePrecision.unknown);
      expect(
        () => storage.parseGoodreads('bad,header\n1,2'),
        throwsA(isA<LibraryFormatException>()),
      );
    },
  );
  test(
    'CSV protects spreadsheet formulas, HTML escapes content, PDF works offline',
    () async {
      final exporter = ExportService(storage),
          books = [
            Book(
              id: 'b',
              title: '=1+1<script>',
              author: 'Émilie',
              notes: '@SUM(A1)',
            ),
          ];
      expect(exporter.csvText(books), contains("'=1+1"));
      expect(exporter.csvText(books), contains("'@SUM"));
      final html = exporter.htmlText(books);
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('Émilie'));
      final pdf = await exporter.pdfBytes(books);
      expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    },
  );
  test('Diagnostics stay local and exclude book content', () async {
    await storage.logError('save', StateError('SECRET BOOK TITLE'));
    final text = await (await storage.file('diagnostics.log')).readAsString();
    expect(text, contains('save StateError'));
    expect(text, isNot(contains('SECRET')));
  });
  test(
    'Expired trash and orphan covers are removed without touching retained covers',
    () async {
      final bytes = img.encodeJpg(img.Image(width: 10, height: 15));
      final path = await storage.storeCover(bytes);
      final active = Book(id: 'a', title: 'Active', coverImagePath: path);
      final expired = Book(
        id: 'd',
        title: 'Deleted',
        deletedAt: DateTime.now().subtract(const Duration(days: 31)),
      );
      await storage.saveBooks([active, expired]);
      expect((await storage.loadBooks()).single.id, 'a');
      expect(await File(path).exists(), isTrue);
      await storage.saveBooks([]);
      await storage.cleanupCovers([]);
      expect(await File(path).exists(), isFalse);
    },
  );
  test(
    'Invalid calendar dates are rejected rather than normalized into a later month',
    () {
      final book = Book(
        id: 'b',
        title: 'B',
        sessions: [ReadingSession(id: 's', startDate: DateTime(2026, 2, 1))],
      ).toJson();
      (book['sessions'] as List<Map<String, dynamic>>).single['startDate'] =
          '2026-02-31T00:00:00.000';
      expect(
        () => storage.parseJson(jsonEncode([book])),
        throwsA(isA<LibraryFormatException>()),
      );
    },
  );
  test('A library of 5000 books still round-trips using JSON', () async {
    final books = List.generate(
      5000,
      (i) => Book(
        id: 'book-$i',
        title: 'Book $i',
        author: 'Author ${i % 25}',
        totalPages: 300,
      ),
    );
    final stopwatch = Stopwatch()..start();
    await storage.saveBooks(books);
    final loaded = await storage.loadBooks();
    stopwatch.stop();
    expect(loaded.length, 5000);
    expect(loaded.last.id, 'book-4999');
    // Recorded in test output to inform the SQLite decision, not a timing gate.
    // ignore: avoid_print
    print('5000-book JSON save + load: ${stopwatch.elapsedMilliseconds} ms');
  });
}
