import 'dart:io';

import 'package:book_companion/main.dart';
import 'package:book_companion/models/book.dart';
import 'package:book_companion/screens/cover_crop_screen.dart';
import 'package:book_companion/services/library_model.dart';
import 'package:book_companion/services/storage_service.dart';
import 'package:book_companion/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../test/support/reading_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: reading lifecycle, restart, complete backup and merge', (
    tester,
  ) async {
    final temporary = await getTemporaryDirectory();
    final directory = await Directory(
      '${temporary.path}/integration-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final storage = StorageService(directory: directory);
    final library = LibraryModel(storage: storage);
    await library.load();
    final settings = ThemeNotifier(storage: storage);
    await settings.load();
    await tester.pumpWidget(
      BookCompanionApp(library: library, settings: settings),
    );
    await tester.pumpAndSettle();
    await exerciseReadingFlow(tester, library);
    final paper = library.books.single;
    await library.addQuote(
      paper,
      const BookQuote(id: 'q', text: 'A memorable passage', page: 25),
    );
    await library.setStatus(paper, BookStatus.onHold);
    await library.setStatus(paper, BookStatus.reading);
    await library.updatePage(paper, 12);
    await tester.pumpAndSettle();
    final source = File('${directory.path}/camera.jpg');
    await source.writeAsBytes(
      img.encodeJpg(img.Image(width: 200, height: 300)),
    );
    final cropFuture = BookCompanionApp.navigator.currentState!.push<String>(
      MaterialPageRoute(builder: (_) => CoverCropScreen(path: source.path)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use cover'));
    final cropped = await cropFuture;
    await tester.pumpAndSettle();
    expect(cropped, isNotNull);
    await library.updateBook(
      library.byId(paper.id)!.copyWith(coverImagePath: cropped),
    );
    expect(
      await File(library.byId(paper.id)!.coverImagePath!).exists(),
      isTrue,
    );
    await library.addBook(
      Book(
        id: 'audio',
        title: 'Audio example',
        format: BookFormat.audiobook,
        totalMinutes: 120,
      ),
    );
    await library.startReading(library.byId('audio')!);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('reading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio example'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Set time'));
    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('progress-input')),
      '1:05',
    );
    await tester.tap(find.text('Save time'));
    await waitFor(
      tester,
      () => library.byId('audio')!.openSession!.currentPage == 65,
    );
    await library.deleteBook('audio');
    expect(library.trash.single.id, 'audio');
    await library.restoreBook('audio');
    expect(library.byId('audio')!.openSession!.currentPage, 65);
    await settings.update({
      'securePreview': true,
      'theme': 'dark',
      'defaultPrecision': 'approximate',
      'firstDayOfWeek': 0,
    });
    expect(
      await LibraryModel.platform.invokeMethod<bool>('securePreviewEnabled'),
      isTrue,
    );
    await settings.update({'securePreview': false});
    expect(
      await LibraryModel.platform.invokeMethod<bool>('securePreviewEnabled'),
      isFalse,
    );
    final disk = await storage.loadBooks();
    expect(disk.first.averageRating, 4);
    final backup = storage.decodeBackup(await storage.backupBytes(disk));
    expect(backup.books.first.sessions.first.currentPage, 120);
    expect(backup.covers.length, 1);
    final snapshotCount = (await storage.snapshots()).length;
    expect(await library.importData(backup, ImportMode.merge), isTrue);
    expect(library.books.length, 2);
    expect(
      (await storage.snapshots()).length,
      greaterThanOrEqualTo(snapshotCount),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await directory.delete(recursive: true);
  });
}
