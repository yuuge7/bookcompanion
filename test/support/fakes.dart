import 'package:book_companion/models/book.dart';
import 'package:book_companion/services/storage_service.dart';
import 'package:book_companion/services/theme_notifier.dart';
import 'dart:io';

class MemoryStorage extends StorageService {
  List<Book> saved = [];
  Map<String, dynamic> settings = {};
  bool failSave = false, failLoad = false;
  int snapshotsTaken = 0;
  ImportData? pickedImport;
  @override
  Future<ImportData?> pickImport() async => pickedImport;
  @override
  Future<List<File>> snapshots() async => [];
  @override
  Future<List<Book>> loadBooks() async {
    if (failLoad) throw const LibraryFormatException('Unreadable library');
    return List.of(saved);
  }

  @override
  Future<void> saveBooks(List<Book> books) async {
    if (failSave) throw StateError('Disk full');
    validate(books);
    saved = List.of(books);
  }

  @override
  Future<Book> prepareCover(Book book) async => book;
  @override
  Future<void> cleanupCovers(List<Book> books) async {}
  @override
  Future<List<Book>> materialize(ImportData data) async => data.books;
  @override
  Future<void> snapshot(List<Book> books, {bool force = false}) async {
    snapshotsTaken++;
  }

  @override
  Future<Map<String, dynamic>> loadSettings() async => Map.of(settings);
  @override
  Future<void> saveSettings(Map<String, dynamic> value) async {
    settings = Map.of(value);
  }

  @override
  Future<void> logError(String operation, Object error) async {}
}

class TestSettings extends ThemeNotifier {
  TestSettings({super.storage}) {
    loaded = true;
    autoSnapshots = false;
  }
  bool authenticationSucceeds = true;
  @override
  Future<bool> authenticate() async => authenticationSucceeds;
  @override
  Future<void> applyPrivacy() async {}
}
