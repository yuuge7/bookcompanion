import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/book.dart';

/// All data lives on-device only, as a single JSON file — same philosophy
/// as mangacompanion. No accounts, no network calls.
class StorageService {
  static const _fileName = 'books.json';

  Future<File> _localFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<Book>> loadBooks() async {
    try {
      final file = await _localFile();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt or unreadable file — start fresh rather than crash.
      return [];
    }
  }

  Future<void> saveBooks(List<Book> books) async {
    final file = await _localFile();
    final jsonList = books.map((b) => b.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  /// Export the current library as a plain JSON array the user picks a
  /// destination for.
  Future<String?> exportBooks(List<Book> books) async {
    final jsonList = books.map((b) => b.toJson()).toList();
    final contents = const JsonEncoder.withIndent('  ').convert(jsonList);

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export book library',
      fileName: 'book_companion_export.json',
      bytes: utf8.encode(contents),
    );
    return savePath;
  }

  /// Import a previously exported JSON array. Returns the parsed books, or
  /// null if the user cancelled.
  Future<List<Book>?> importBooks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final raw = await file.readAsString();
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Book.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
