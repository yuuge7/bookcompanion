import 'package:diacritic/diacritic.dart';

import '../models/book.dart';

enum LibrarySort { title, author, dateAdded, lastRead, rating, progress }

extension LibrarySortLabel on LibrarySort {
  String get label => switch (this) {
    LibrarySort.title => 'Title',
    LibrarySort.author => 'Author',
    LibrarySort.dateAdded => 'Date added',
    LibrarySort.lastRead => 'Last read',
    LibrarySort.rating => 'Rating',
    LibrarySort.progress => 'Progress',
  };
}

String normalize(String text) => removeDiacritics(text).toLowerCase().trim();
bool _near(String a, String b) {
  if ((a.length - b.length).abs() > 1) return false;
  if (a == b) return true;
  if (a.length == b.length) {
    final diff = <int>[];
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) diff.add(i);
    }
    return diff.length == 1 ||
        (diff.length == 2 &&
            diff[1] == diff[0] + 1 &&
            a[diff[0]] == b[diff[1]] &&
            a[diff[1]] == b[diff[0]]);
  }
  final short = a.length < b.length ? a : b;
  final long = a.length < b.length ? b : a;
  var index = 0;
  while (index < short.length && short[index] == long[index]) {
    index++;
  }
  return short.substring(index) == long.substring(index + 1);
}

bool matchesBook(Book b, String query) {
  final haystack = normalize(
    [
      b.title,
      b.subtitle,
      b.author,
      b.notes,
      b.isbn,
      b.series,
      b.publisher,
      ...b.tags,
      ...b.quotes.map((q) => q.text),
    ].join(' '),
  );
  return normalize(query)
      .split(RegExp(r'\s+'))
      .every(
        (term) =>
            term.isEmpty ||
            haystack.contains(term) ||
            (term.length >= 4 &&
                haystack
                    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
                    .any((word) => _near(term, word))),
      );
}

class LibraryQuery {
  String search = '';
  LibrarySort sort = LibrarySort.lastRead;
  bool descending = true;
  String? tag, series;
  BookFormat? format;
  int? finishedYear, rating;
  bool get hasFilters =>
      tag != null ||
      series != null ||
      format != null ||
      finishedYear != null ||
      rating != null;
  List<Book> apply(List<Book> books) {
    final result = books
        .where(
          (b) =>
              matchesBook(b, search) &&
              (tag == null || b.tags.contains(tag)) &&
              (series == null || b.series == series) &&
              (format == null || b.format == format) &&
              (finishedYear == null ||
                  b.sessions.any(
                    (s) =>
                        s.endDate?.year == finishedYear &&
                        s.precision.name != 'unknown',
                  )) &&
              (rating == null || b.averageRating?.round() == rating),
        )
        .toList();
    result.sort((a, b) {
      final comparison = switch (sort) {
        LibrarySort.title => normalize(a.title).compareTo(normalize(b.title)),
        LibrarySort.author => normalize(
          a.author,
        ).compareTo(normalize(b.author)),
        LibrarySort.dateAdded => a.createdAt.compareTo(b.createdAt),
        LibrarySort.lastRead => a.lastRead.compareTo(b.lastRead),
        LibrarySort.rating => (a.averageRating ?? 0).compareTo(
          b.averageRating ?? 0,
        ),
        LibrarySort.progress => a.progress.compareTo(b.progress),
      };
      return comparison == 0
          ? a.id.compareTo(b.id)
          : descending
          ? -comparison
          : comparison;
    });
    return result;
  }
}
