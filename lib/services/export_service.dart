import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/book.dart';
import 'storage_service.dart';

class ExportService {
  ExportService(this.storage);
  final StorageService storage;
  String csvText(List<Book> books) {
    String safe(String value) =>
        RegExp(r'^[\s]*[=+@\-\t\r]').hasMatch(value) ? "'$value" : value;
    return Csv(addBom: true).encode([
      [
        'Title',
        'Author',
        'Subtitle',
        'ISBN',
        'Publisher',
        'Year',
        'Language',
        'Format',
        'Series',
        'Series number',
        'Tags',
        'Status',
        'Total pages',
        'Duration minutes',
        'Current progress',
        'Completed reads',
        'Average rating',
        'Notes',
        'Created',
        'Updated',
      ],
      ...books.map(
        (b) => [
          safe(b.title),
          safe(b.author),
          safe(b.subtitle),
          safe(b.isbn),
          safe(b.publisher),
          b.year ?? '',
          safe(b.language),
          b.format.label,
          safe(b.series),
          safe(b.seriesNumber),
          safe(b.tags.join(', ')),
          b.status.label,
          b.totalPages ?? '',
          b.totalMinutes ?? '',
          b.openSession?.currentPage ?? '',
          b.timesRead,
          b.averageRating ?? '',
          safe(b.notes),
          b.createdAt.toIso8601String(),
          b.updatedAt.toIso8601String(),
        ],
      ),
    ]);
  }

  String htmlText(List<Book> books) {
    const escape = HtmlEscape();
    String e(String v) => escape.convert(v);
    return '<!doctype html><html lang="en"><meta charset="utf-8"><title>Book Companion reading list</title>'
        '<style>body{font:16px Georgia,serif;margin:32px;color:#25251f}table{border-collapse:collapse;width:100%}'
        'th,td{text-align:left;border-bottom:1px solid #ccc;padding:10px;vertical-align:top}small{color:#555}'
        '@media print{body{margin:0}thead{display:table-header-group}tr{break-inside:avoid}}</style>'
        '<h1>My reading list</h1><p>${books.length} books · Exported ${DateTime.now().toIso8601String().substring(0, 10)}</p>'
        '<table><thead><tr><th>Book</th><th>Shelf</th><th>Format / length</th><th>Reads / rating</th></tr></thead><tbody>'
        '${books.map((b) => '<tr><td><strong>${e(b.title)}</strong><br>${e(b.author)}<br><small>${e([b.series, ...b.tags].where((v) => v.isNotEmpty).join(' · '))}</small></td>'
            '<td>${b.status.label}</td><td>${b.format.label}<br>${b.progressTotal == null ? '' : b.progressLabel(b.progressTotal!)} ${b.isAudio ? 'hours' : 'pages'}</td><td>${b.timesRead} / ${b.averageRating?.toStringAsFixed(1) ?? 'unrated'}</td></tr>').join()}'
        '</tbody></table></html>';
  }

  Future<Uint8List> pdfBytes(List<Book> books) async {
    final document = pw.Document();
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    document.addPage(
      pw.MultiPage(
        maxPages: (books.length / 10).ceil() + 20,
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: regular),
        footer: (ctx) => pw.Text(
          'Book Companion · ${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        build: (_) => [
          pw.Header(level: 0, text: 'My reading list'),
          pw.Text('${books.length} books'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Book / author', 'Shelf', 'Format', 'Reads / rating'],
            cellStyle: const pw.TextStyle(fontSize: 10),
            data: books
                .map(
                  (b) => [
                    '${b.title}\n${b.author}',
                    b.status.label,
                    b.format.label,
                    '${b.timesRead} / ${b.averageRating?.toStringAsFixed(1) ?? 'unrated'}',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<String?> export(List<Book> books, String format) async {
    final List<int> bytes = switch (format) {
      'json' => utf8.encode(
        const JsonEncoder.withIndent('  ').convert(storage.envelope(books)),
      ),
      'csv' => utf8.encode(csvText(books)),
      'html' => utf8.encode(htmlText(books)),
      'pdf' => await pdfBytes(books),
      _ => await storage.backupBytes(books),
    };
    return storage.saveExport('book_companion.$format', bytes);
  }
}
