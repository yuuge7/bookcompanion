import 'package:diacritic/diacritic.dart';

import '../models/book.dart';

enum LibrarySort {
  title,
  author,
  dateAdded,
  lastRead,
  lastEdited,
  rating,
  progress,
}

extension LibrarySortLabel on LibrarySort {
  String get label => switch (this) {
    LibrarySort.title => 'Title',
    LibrarySort.author => 'Author',
    LibrarySort.dateAdded => 'Date added',
    LibrarySort.lastRead => 'Last read',
    LibrarySort.lastEdited => 'Last edited',
    LibrarySort.rating => 'Rating',
    LibrarySort.progress => 'Progress',
  };
  bool get defaultDescending =>
      this != LibrarySort.title && this != LibrarySort.author;
  String get ascendingLabel => switch (this) {
    LibrarySort.title || LibrarySort.author => 'A–Z',
    LibrarySort.dateAdded ||
    LibrarySort.lastRead ||
    LibrarySort.lastEdited => 'Oldest first',
    LibrarySort.rating => 'Lowest first',
    LibrarySort.progress => 'Least first',
  };
  String get descendingLabel => switch (this) {
    LibrarySort.title || LibrarySort.author => 'Z–A',
    LibrarySort.dateAdded ||
    LibrarySort.lastRead ||
    LibrarySort.lastEdited => 'Newest first',
    LibrarySort.rating => 'Highest first',
    LibrarySort.progress => 'Most first',
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
  LibrarySort sort = LibrarySort.title;
  bool descending = false;
  String? tag, series;
  BookFormat? format;
  int? finishedYear, rating;
  LibraryQuery copy() => LibraryQuery()
    ..search = search
    ..sort = sort
    ..descending = descending
    ..tag = tag
    ..series = series
    ..format = format
    ..finishedYear = finishedYear
    ..rating = rating;
  void clearFilters() {
    tag = null;
    series = null;
    format = null;
    finishedYear = null;
    rating = null;
  }

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
              (format == null ||
                  (b.sessions.isEmpty
                      ? b.format == format
                      : b.sessions.any((s) => s.format == format))) &&
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
      // Unknown dates and unrated books stay at the end in either direction.
      if (sort == LibrarySort.lastRead &&
          (a.lastRead == null || b.lastRead == null)) {
        if (a.lastRead != b.lastRead) return a.lastRead == null ? 1 : -1;
      }
      if (sort == LibrarySort.rating &&
          (a.averageRating == null || b.averageRating == null)) {
        if (a.averageRating != b.averageRating) {
          return a.averageRating == null ? 1 : -1;
        }
      }
      final comparison = switch (sort) {
        LibrarySort.title => normalize(a.title).compareTo(normalize(b.title)),
        LibrarySort.author => normalize(
          a.author,
        ).compareTo(normalize(b.author)),
        LibrarySort.dateAdded => a.createdAt.compareTo(b.createdAt),
        LibrarySort.lastRead =>
          a.lastRead == null || b.lastRead == null
              ? 0
              : a.lastRead!.compareTo(b.lastRead!),
        LibrarySort.lastEdited => a.updatedAt.compareTo(b.updatedAt),
        LibrarySort.rating => (a.averageRating ?? 0).compareTo(
          b.averageRating ?? 0,
        ),
        LibrarySort.progress => a.progress.compareTo(b.progress),
      };
      return comparison == 0
          ? normalize(a.title).compareTo(normalize(b.title)) != 0
                ? normalize(a.title).compareTo(normalize(b.title))
                : a.id.compareTo(b.id)
          : descending
          ? -comparison
          : comparison;
    });
    return result;
  }
}
