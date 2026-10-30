import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import '../models/reading_session.dart';

class LibraryFormatException implements Exception {
  const LibraryFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ImportData {
  ImportData(List<Book> books, {Map<String, Uint8List> covers = const {}})
    : books = List.unmodifiable(
        books.where(
          (b) =>
              b.deletedAt == null ||
              b.deletedAt!.isAfter(
                DateTime.now().subtract(const Duration(days: 30)),
              ),
        ),
      ),
      covers = Map.unmodifiable(covers);
  final List<Book> books;
  final Map<String, Uint8List> covers;
}

/// Re-encoding pixel data (rather than copying EXIF) removes GPS and metadata.
Uint8List cleanCover(Uint8List bytes) {
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  if (info == null || info.width * info.height > 24000000) {
    throw const LibraryFormatException(
      'Cover must be a supported image under 24 megapixels.',
    );
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const LibraryFormatException('Cover is not a supported image.');
  }
  var upright = img.bakeOrientation(decoded);
  if (upright.width > 800 || upright.height > 1200) {
    final scale = min(800 / upright.width, 1200 / upright.height);
    upright = img.copyResize(
      upright,
      width: max(1, (upright.width * scale).floor()),
      height: max(1, (upright.height * scale).floor()),
    );
  }
  final clean = img.Image(width: upright.width, height: upright.height);
  img.compositeImage(clean, upright);
  return img.encodeJpg(clean, quality: 85);
}

class StorageService {
  StorageService({Directory? directory}) : _directory = directory;
  final Directory? _directory;
  static const maxImportBytes = 100 * 1024 * 1024;
  Future<Directory> get directory async =>
      _directory ?? await getApplicationDocumentsDirectory();
  Future<File> file(String name) async =>
      File('${(await directory).path}/$name');

  Map<String, dynamic> envelope(List<Book> books) => {
    'app': 'book_companion',
    'schemaVersion': 2,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'books': books.map((b) => b.toJson()).toList(),
  };
  Future<void> atomicWrite(File target, List<int> bytes) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(target.path);
  }

  Future<List<Book>> loadBooks() async {
    final saved = await file('books.json');
    if (!await saved.exists()) return [];
    final parsed = parseJson(await saved.readAsString());
    final migrated = <Book>[];
    var changed = false;
    for (final book in parsed) {
      if (book.deletedAt != null &&
          !book.deletedAt!.isAfter(
            DateTime.now().subtract(const Duration(days: 30)),
          )) {
        changed = true;
        continue;
      }
      final prepared = await prepareCover(book);
      changed = changed || prepared.coverImagePath != book.coverImagePath;
      migrated.add(prepared);
    }
    if (changed) await saveBooks(migrated);
    await cleanupCovers(migrated);
    return migrated;
  }

  Future<void> saveBooks(List<Book> books) async {
    validate(books);
    await atomicWrite(
      await file('books.json'),
      utf8.encode(jsonEncode(envelope(books))),
    );
  }

  List<Book> parseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final List<dynamic> rows;
      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded['app'] == 'book_companion' &&
          decoded['schemaVersion'] == 2 &&
          decoded['books'] is List) {
        rows = decoded['books'] as List<dynamic>;
      } else {
        throw const LibraryFormatException(
          'Expected a Book Companion library (schema 2 or legacy array).',
        );
      }
      final books = <Book>[];
      for (var i = 0; i < rows.length; i++) {
        try {
          books.add(Book.fromJson(rows[i] as Map<String, dynamic>));
        } catch (_) {
          throw LibraryFormatException(
            'Book ${i + 1}: invalid field, date, format or status.',
          );
        }
      }
      validate(books);
      return books;
    } on LibraryFormatException {
      rethrow;
    } catch (_) {
      throw const LibraryFormatException('The file is not valid library JSON.');
    }
  }

  void validate(List<Book> books) {
    final ids = <String>{};
    for (var i = 0; i < books.length; i++) {
      final b = books[i];
      void fail(String reason) =>
          throw LibraryFormatException('Book ${i + 1} (${b.title}): $reason');
      if (b.id.trim().isEmpty || !ids.add(b.id)) {
        fail('missing or duplicate id.');
      }
      if (b.title.trim().isEmpty) fail('title is required.');
      if (b.totalPages != null && b.totalPages! <= 0) {
        fail('total pages must be positive.');
      }
      if (b.totalMinutes != null && b.totalMinutes! <= 0) {
        fail('audio duration must be positive.');
      }
      if (b.year != null && (b.year! < 1 || b.year! > 9999)) {
        fail('invalid publication year.');
      }
      if (b.updatedAt.isBefore(b.createdAt)) {
        fail('updated date precedes created date.');
      }
      final sessionIds = <String>{};
      if (b.sessions.where((s) => s.isOpen).length > 1) {
        fail('more than one open reading session.');
      }
      for (final s in b.sessions) {
        if (s.id.isEmpty || !sessionIds.add(s.id)) {
          fail('duplicate or missing session id.');
        }
        if (s.endDate != null && _day(s.endDate!).isBefore(_day(s.startDate))) {
          fail('end date precedes start date.');
        }
        if (s.rating != null && (s.rating! < 1 || s.rating! > 5)) {
          fail('rating must be between 1 and 5.');
        }
        if (s.currentPage < 0 ||
            (b.progressTotal != null && s.currentPage > b.progressTotal!)) {
          fail('progress exceeds the book length.');
        }
        DateTime? previous;
        for (final p in s.progress) {
          if (p.page < 0 ||
              (p.fromPage != null && p.fromPage! < 0) ||
              (b.progressTotal != null && p.page > b.progressTotal!) ||
              (previous != null && p.date.isBefore(previous))) {
            fail('invalid progress log.');
          }
          previous = p.date;
        }
      }
      final quoteIds = <String>{};
      for (final q in b.quotes) {
        if (q.id.isEmpty ||
            !quoteIds.add(q.id) ||
            q.text.trim().isEmpty ||
            (q.page != null &&
                (q.page! < 0 ||
                    (b.progressTotal != null && q.page! > b.progressTotal!)))) {
          fail('invalid quote or quote location.');
        }
      }
    }
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<String> storeCover(Uint8List bytes) async {
    if (bytes.length > 20 * 1024 * 1024) {
      throw const LibraryFormatException('Cover must be under 20 MB.');
    }
    final clean = await compute(cleanCover, bytes);
    final target = await file('covers/${sha256.convert(clean)}.jpg');
    if (!await target.exists()) await atomicWrite(target, clean);
    return target.path;
  }

  Future<void> cleanupCovers(List<Book> books) async {
    try {
      final covers = Directory(p.join((await directory).path, 'covers'));
      if (!await covers.exists()) return;
      final retained = books
          .where((b) => b.coverImagePath != null)
          .map((b) => p.normalize(p.absolute(b.coverImagePath!)))
          .toSet();
      await for (final entry in covers.list(followLinks: false)) {
        if (entry is File &&
            RegExp(r'^[a-f0-9]{64}\.jpg$').hasMatch(p.basename(entry.path)) &&
            !retained.contains(p.normalize(p.absolute(entry.path)))) {
          await entry.delete();
        }
      }
    } catch (e) {
      await logError('cover_cleanup', e);
    }
  }

  Future<Book> prepareCover(Book book) async {
    final path = book.coverImagePath;
    if (path == null) return book;
    final cover = File(path);
    if (!await cover.exists()) {
      return book.copyWith(coverImagePath: null, updatedAt: book.updatedAt);
    }
    // Existing content-addressed covers are already sanitized.
    if (p.equals(cover.parent.path, p.join((await directory).path, 'covers')) &&
        RegExp(r'^[a-f0-9]{64}\.jpg$').hasMatch(p.basename(cover.path))) {
      return book;
    }
    return book.copyWith(
      coverImagePath: await storeCover(await cover.readAsBytes()),
      updatedAt: book.updatedAt,
    );
  }

  Future<Uint8List> backupBytes(List<Book> books) async {
    final archive = Archive();
    final hashes = <String, String>{};
    final portable = <Book>[];
    for (final book in books) {
      String? relative;
      if (book.coverImagePath != null &&
          await File(book.coverImagePath!).exists()) {
        final prepared = await prepareCover(book);
        final clean = await File(prepared.coverImagePath!).readAsBytes();
        relative = 'covers/${sha256.convert(clean)}.jpg';
        if (!hashes.containsKey(relative)) {
          hashes[relative] = sha256.convert(clean).toString();
          archive.addFile(ArchiveFile(relative, clean.length, clean));
        }
      }
      portable.add(
        book.copyWith(coverImagePath: relative, updatedAt: book.updatedAt),
      );
    }
    final library = utf8.encode(jsonEncode(envelope(portable)));
    hashes['library.json'] = sha256.convert(library).toString();
    archive.addFile(ArchiveFile('library.json', library.length, library));
    const version = String.fromEnvironment(
      'FLUTTER_BUILD_NAME',
      defaultValue: 'development',
    );
    final manifest = utf8.encode(
      jsonEncode({
        'app': 'book_companion',
        'schemaVersion': 2,
        'appVersion': version,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'bookCount': books.length,
        'sha256': hashes['library.json'],
        'files': hashes,
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  ImportData decodeBackup(Uint8List bytes) {
    try {
      if (bytes.length > maxImportBytes) {
        throw const LibraryFormatException('Backup exceeds 100 MB.');
      }
      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(bytes);
      final names = decoder.directory.fileHeaders
          .map((h) => h.filename)
          .toList();
      if (names.toSet().length != names.length) {
        throw const LibraryFormatException('Duplicate backup file.');
      }
      final files = <String, Uint8List>{};
      var total = 0;
      for (final entry in archive.files) {
        if (!entry.isFile || entry.isSymbolicLink) {
          throw const LibraryFormatException('Invalid backup entry.');
        }
        if (entry.name != 'library.json' &&
            entry.name != 'manifest.json' &&
            !RegExp(r'^covers/[a-f0-9]{64}\.jpg$').hasMatch(entry.name)) {
          throw const LibraryFormatException(
            'Backup contains an unsafe file path.',
          );
        }
        total += entry.size;
        if (total > maxImportBytes) {
          throw const LibraryFormatException('Expanded backup exceeds 100 MB.');
        }
        if (files.containsKey(entry.name)) {
          throw const LibraryFormatException('Duplicate backup file.');
        }
        files[entry.name] = entry.content;
      }
      final manifest =
          jsonDecode(utf8.decode(files['manifest.json']!))
              as Map<String, dynamic>;
      if (manifest['app'] != 'book_companion' ||
          manifest['schemaVersion'] != 2) {
        throw const LibraryFormatException('Unsupported backup version.');
      }
      final hashes = manifest['files'] as Map<String, dynamic>;
      if (hashes.length != files.length - 1) {
        throw const LibraryFormatException('Incomplete backup manifest.');
      }
      for (final hash in hashes.entries) {
        final content = files[hash.key];
        if (content == null ||
            sha256.convert(content).toString() != hash.value) {
          throw LibraryFormatException(
            'Checksum failed for ${hash.key}. Nothing was imported.',
          );
        }
      }
      if (manifest['sha256'] != hashes['library.json']) {
        throw const LibraryFormatException('Library checksum is missing.');
      }
      final books = parseJson(utf8.decode(files['library.json']!));
      if (books.length != manifest['bookCount']) {
        throw const LibraryFormatException(
          'Book count does not match manifest.',
        );
      }
      for (final b in books) {
        if (b.coverImagePath != null &&
            (!b.coverImagePath!.startsWith('covers/') ||
                !files.containsKey(b.coverImagePath))) {
          throw const LibraryFormatException(
            'A cover is missing from the backup.',
          );
        }
      }
      return ImportData(
        books,
        covers: Map.fromEntries(
          files.entries.where((e) => e.key.startsWith('covers/')),
        ),
      );
    } on LibraryFormatException {
      rethrow;
    } catch (_) {
      throw const LibraryFormatException(
        'Damaged or incomplete backup. Nothing was imported.',
      );
    }
  }

  Future<ImportData?> pickImport() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null) return null;
    final source = File(path);
    if (await source.length() > maxImportBytes) {
      throw const LibraryFormatException('Import file exceeds 100 MB.');
    }
    final bytes = await source.readAsBytes();
    if (path.toLowerCase().endsWith('.csv')) {
      return ImportData(parseGoodreads(utf8.decode(bytes)));
    }
    if (bytes.length >= 2 && bytes[0] == 80 && bytes[1] == 75) {
      return decodeBackup(bytes);
    }
    // JSON never grants access to arbitrary paths on the importing phone.
    return ImportData(
      parseJson(utf8.decode(bytes))
          .map((b) => b.copyWith(coverImagePath: null, updatedAt: b.updatedAt))
          .toList(),
    );
  }

  Future<List<Book>> materialize(ImportData data) async {
    final paths = <String, String>{};
    for (final cover in data.covers.entries) {
      paths[cover.key] = await storeCover(cover.value);
    }
    return data.books
        .map(
          (b) => b.copyWith(
            coverImagePath: paths[b.coverImagePath],
            updatedAt: b.updatedAt,
          ),
        )
        .toList();
  }

  Future<String?> exportBooks(List<Book> books) async =>
      saveExport('book_companion.bcbackup', await backupBytes(books));
  Future<String?> saveExport(String name, List<int> bytes) =>
      FilePicker.platform.saveFile(
        dialogTitle: 'Save $name',
        fileName: name,
        bytes: Uint8List.fromList(bytes),
      );
  Future<void> snapshot(List<Book> books, {bool force = false}) async {
    final folder = Directory('${(await directory).path}/snapshots');
    await folder.create(recursive: true);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final name = force ? '${DateTime.now().microsecondsSinceEpoch}' : date;
    final target = File('${folder.path}/$name.bcbackup');
    if (!await target.exists()) {
      await atomicWrite(target, await backupBytes(books));
    }
    final backups = await snapshots();
    for (final obsolete in backups.skip(10)) {
      await obsolete.delete();
    }
  }

  Future<List<File>> snapshots() async {
    final folder = Directory('${(await directory).path}/snapshots');
    if (!await folder.exists()) return [];
    final files = await folder
        .list()
        .where((f) => f is File && f.path.endsWith('.bcbackup'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  Future<Map<String, dynamic>> loadSettings() async {
    final saved = await file('settings.json');
    return await saved.exists()
        ? jsonDecode(await saved.readAsString()) as Map<String, dynamic>
        : {};
  }

  Future<void> saveSettings(Map<String, dynamic> value) async =>
      atomicWrite(await file('settings.json'), utf8.encode(jsonEncode(value)));
  Future<void> logError(String operation, Object error) async {
    try {
      final log = await file('diagnostics.log');
      final old = await log.exists() ? await log.readAsString() : '';
      // No book titles, cover paths, notes or imported contents in diagnostics.
      final lines =
          '$old${DateTime.now().toUtc().toIso8601String()} $operation ${error.runtimeType}\n'
              .split('\n');
      await atomicWrite(
        log,
        utf8.encode(
          lines.skip(lines.length > 200 ? lines.length - 200 : 0).join('\n'),
        ),
      );
    } catch (_) {
      /* Logging must never prevent recovery. */
    }
  }

  List<Book> parseGoodreads(String raw) {
    final rows = csv.decode(raw);
    if (rows.isEmpty) throw const LibraryFormatException('CSV is empty.');
    final header = rows.first.map((e) => e.toString()).toList();
    if (!header.contains('Title') ||
        !header.contains('Book Id') ||
        !header.contains('Exclusive Shelf')) {
      throw const LibraryFormatException(
        'Expected a Goodreads library CSV export.',
      );
    }
    final books = <Book>[];
    for (var i = 1; i < rows.length; i++) {
      String field(String name) {
        final index = header.indexOf(name);
        return index < 0 || index >= rows[i].length
            ? ''
            : rows[i][index].toString();
      }

      final id = field('Book Id');
      final status = switch (field('Exclusive Shelf')) {
        'read' => BookStatus.read,
        'currently-reading' => BookStatus.reading,
        _ => BookStatus.toRead,
      };
      final added =
          DateTime.tryParse(field('Date Added').replaceAll('/', '-')) ??
          DateTime.utc(1970);
      final end = DateTime.tryParse(field('Date Read').replaceAll('/', '-'));
      final pages = int.tryParse(field('Number of Pages'));
      final rating = int.tryParse(field('My Rating'));
      books.add(
        Book(
          id: 'goodreads-$id',
          title: field('Title'),
          author: field('Author'),
          isbn: field('ISBN13').replaceAll(RegExp('[="]'), ''),
          publisher: field('Publisher'),
          year: int.tryParse(field('Year Published')),
          totalPages: pages == 0 ? null : pages,
          status: status,
          notes: field('My Review'),
          tags: field(
            'Bookshelves',
          ).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          createdAt: added,
          updatedAt: end != null && end.isAfter(added) ? end : added,
          sessions: status == BookStatus.toRead
              ? []
              : [
                  ReadingSession(
                    id: 'goodreads-$id-read',
                    startDate: end ?? added,
                    endDate: status == BookStatus.read ? end ?? added : null,
                    precision: end == null
                        ? DatePrecision.unknown
                        : DatePrecision.exact,
                    rating: rating == 0 ? null : rating,
                    currentPage: status == BookStatus.read ? pages ?? 0 : 0,
                  ),
                ],
        ),
      );
    }
    validate(books);
    return books;
  }
}
