import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/book.dart';

/// Raised when a file exists but isn't a library this app can read. The
/// message is for the log; screens write their own copy rather than
/// printing this to the user.
class LibraryFormatException implements Exception {
  LibraryFormatException(this.message);
  final String message;
  @override
  String toString() => 'LibraryFormatException: $message';
}

/// All data lives on-device only, as a single JSON file — same philosophy
/// as mangacompanion. No accounts, no network calls.
class StorageService {
  static const _fileName = 'books.json';

  Future<File> _localFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Returns an empty library when there is nothing saved yet.
  ///
  /// Throws [LibraryFormatException] when a file *is* there but can't be
  /// parsed. That case used to return an empty list, which meant the next
  /// save quietly wrote `[]` over the only copy of someone's library — so
  /// it now surfaces instead, and [LibraryModel] stops writing.
  Future<List<Book>> loadBooks() async {
    final file = await _localFile();
    if (!await file.exists()) return [];

    final String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException catch (e) {
      throw LibraryFormatException('could not read books.json: ${e.message}');
    }
    if (raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw LibraryFormatException('books.json is not a readable library: $e');
    }
  }

  Future<void> saveBooks(List<Book> books) async {
    final file = await _localFile();
    final jsonList = books.map((b) => b.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  /// Export the current library as a plain JSON array the user picks a
  /// destination for. Returns null if the user cancelled.
  Future<String?> exportBooks(List<Book> books) async {
    final jsonList = books.map((b) => b.toJson()).toList();
    final contents = const JsonEncoder.withIndent('  ').convert(jsonList);

    return FilePicker.platform.saveFile(
      dialogTitle: 'Export book library',
      fileName: 'book_companion_export.json',
      bytes: utf8.encode(contents),
    );
  }

  /// Import a previously exported JSON array. Returns the parsed books, or
  /// null if the user cancelled. Throws [LibraryFormatException] if the
  /// picked file isn't an export from this app.
  Future<List<Book>?> importBooks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw LibraryFormatException('picked file is not a library export: $e');
    }
  }
}
