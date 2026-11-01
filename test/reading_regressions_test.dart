import 'dart:convert';
import 'dart:typed_data';

import 'package:book_companion/main.dart';
import 'package:book_companion/models/book.dart';
import 'package:book_companion/models/reading_session.dart';
import 'package:book_companion/services/library_model.dart';
import 'package:book_companion/services/library_query.dart';
import 'package:book_companion/services/reading_stats.dart';
import 'package:book_companion/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/fakes.dart';
import 'support/regression_flows.dart';

class ReviewMemoryStorage extends MemoryStorage {
  Uint8List? image;
  @override
  Future<String?> saveExport(String name, List<int> bytes) async {
    image = Uint8List.fromList(bytes);
    return name;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LibraryModel.platform, (_) async => null);
  });
  test(
    'Legacy audio sessions inherit edition once; mixed rereads survive JSON and backups',
    () async {
      final storage = StorageService();
      final legacy = Book(
        id: 'legacy',
        title: 'Audio',
        format: BookFormat.audiobook,
        totalMinutes: 120,
        sessions: [
          ReadingSession(
            id: 'old',
            startDate: DateTime(2024),
            endDate: DateTime(2024, 2),
            currentPage: 120,
          ),
        ],
      ).toJson();
      final legacySession =
          (legacy['sessions'] as List<dynamic>).first as Map<String, dynamic>;
      legacySession.remove('format');
      legacySession.remove('totalLength');
      final migrated = Book.fromJson(legacy);
      expect(migrated.sessions.single.format, BookFormat.audiobook);
      expect(migrated.sessions.single.totalLength, 120);
      final mixed = migrated.copyWith(
        format: BookFormat.paperback,
        totalPages: 300,
        sessions: [
          ...migrated.sessions,
          ReadingSession(
            id: 'new',
            startDate: DateTime(2025),
            endDate: DateTime(2025, 2),
            format: BookFormat.paperback,
            totalLength: 300,
            currentPage: 300,
          ),
        ],
      );
      final restored = storage
          .decodeBackup(await storage.backupBytes([mixed]))
          .books
          .single;
      expect(restored.toJson(), mixed.toJson());
      expect(
        Book.fromJson(
          jsonDecode(jsonEncode(mixed.toJson())) as Map<String, dynamic>,
        ).toJson(),
        mixed.toJson(),
      );
      expect(ReadingStats([restored]).pages, 300);
      expect(ReadingStats([restored]).minutes, 120);
      expect(ReadingStats([restored], year: 2024).formats, {'Audiobook': 1});
      expect(ReadingStats([restored], year: 2025).formats, {'Paperback': 1});
      expect(
        (LibraryQuery()..format = BookFormat.audiobook).apply([restored]),
        hasLength(1),
      );
      storage.validate([mixed]);
      expect(
        () => storage.validate([
          mixed.copyWith(
            sessions: [mixed.sessions.last.copyWith(currentPage: 301)],
          ),
        ]),
        throwsA(isA<LibraryFormatException>()),
      );
    },
  );
  test(
    'Editing history does not move last read; unknown and unrated values sort last',
    () {
      final books = queryBooks();
      final edited = books.first.copyWith(
        sessions: books.first.sessions
            .map((s) => s.copyWith(rating: 2, updatedAt: DateTime(2030)))
            .toList(),
      );
      expect(edited.lastRead, DateTime(2026, 1, 1));
      final unknown = Book(id: 'unknown', title: 'Unknown');
      for (final descending in [true, false]) {
        expect(
          (LibraryQuery()
                ..sort = LibrarySort.lastRead
                ..descending = descending)
              .apply([...books, unknown])
              .last
              .id,
          'unknown',
        );
        expect(
          (LibraryQuery()
                ..sort = LibrarySort.rating
                ..descending = descending)
              .apply([...books, unknown])
              .last
              .id,
          'unknown',
        );
      }
    },
  );
  testWidgets(
    'Every sort direction, combined filters, cancel, clear and All work through the UI',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryStorage()..saved = queryBooks();
      final library = LibraryModel(storage: storage);
      await library.load();
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: TestSettings()),
      );
      await tester.pumpAndSettle();
      await exerciseQueryControls(tester);
    },
  );
  testWidgets(
    'Formats belong to individual reads, including completed edits and audio progress',
    (tester) async {
      final storage = MemoryStorage()..saved = [rereadBook()];
      final library = LibraryModel(storage: storage);
      await library.load();
      final settings = TestSettings()..defaultPrecision = DatePrecision.unknown;
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: settings),
      );
      await tester.pumpAndSettle();
      await exerciseReadFormats(tester, library);
    },
  );
  testWidgets(
    'Year review scrolls to its footer with large text and exports the complete PNG',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 32);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final storage = ReviewMemoryStorage()..saved = reviewBooks();
      final library = LibraryModel(storage: storage);
      await library.load();
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: TestSettings()),
      );
      await tester.pumpAndSettle();
      await exerciseYearReview(tester);
      await tester.runAsync(() async {
        for (var i = 0; i < 50 && storage.image == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pumpAndSettle();
      expect(storage.image, isNotNull);
      final image = img.decodePng(storage.image!);
      expect(image, isNotNull);
      expect(image!.height, greaterThan(800 * 3));
      expect(find.text('Year in Review image saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
