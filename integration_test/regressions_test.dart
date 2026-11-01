import 'dart:io';
import 'dart:typed_data';

import 'package:book_companion/main.dart';
import 'package:book_companion/services/library_model.dart';
import 'package:book_companion/services/storage_service.dart';
import 'package:book_companion/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/reading_flow.dart';
import '../test/support/regression_flows.dart';

class ReviewStorage extends StorageService {
  ReviewStorage(Directory folder) : super(directory: folder);
  Uint8List? image;
  @override
  Future<String?> saveExport(String name, List<int> bytes) async {
    final target = await file(name);
    await target.writeAsBytes(bytes, flush: true);
    image = Uint8List.fromList(bytes);
    return target.path;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<(ReviewStorage, LibraryModel, ThemeNotifier)> harness() async {
    final temp = await getTemporaryDirectory();
    final folder = await Directory(
      '${temp.path}/regressions-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final storage = ReviewStorage(folder);
    final model = LibraryModel(storage: storage)..autoSnapshots = false;
    await model.load();
    final settings = ThemeNotifier(storage: storage);
    await settings.load();
    await settings.update({
      'defaultPrecision': 'unknown',
      'autoSnapshots': false,
    });
    addTearDown(() async => folder.delete(recursive: true));
    return (storage, model, settings);
  }

  testWidgets('Android: all sort directions and combined filter controls', (
    tester,
  ) async {
    final (storage, library, settings) = await harness();
    await storage.saveBooks(queryBooks());
    await library.load();
    await tester.pumpWidget(
      BookCompanionApp(library: library, settings: settings),
    );
    await tester.pumpAndSettle();
    await exerciseQueryControls(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'Android: ebook, paperback, hardcover and audio rereads persist separately',
    (tester) async {
      final (storage, library, settings) = await harness();
      await storage.saveBooks([rereadBook()]);
      await library.load();
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: settings),
      );
      await tester.pumpAndSettle();
      await exerciseReadFormats(tester, library);
      final disk = await storage.loadBooks();
      expect(disk.single.toJson(), library.books.single.toJson());
      final backup = storage.decodeBackup(await storage.backupBytes(disk));
      expect(backup.books.single.toJson(), disk.single.toJson());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Android: large-text year review reaches its footer and saves a full PNG',
    (tester) async {
      final (storage, library, settings) = await harness();
      await storage.saveBooks(reviewBooks());
      await library.load();
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        BookCompanionApp(library: library, settings: settings),
      );
      await tester.pumpAndSettle();
      await exerciseYearReview(tester);
      await waitFor(tester, () => storage.image != null);
      final image = img.decodePng(storage.image!);
      expect(image, isNotNull);
      expect(image!.height, greaterThan(2000));
      expect(find.text('Year in Review image saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
