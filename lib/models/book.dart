import 'reading_session.dart';
import 'book_format.dart';
export 'book_format.dart';

enum BookStatus { toRead, reading, read, onHold, dropped }

extension BookStatusLabel on BookStatus {
  String get label => switch (this) {
    BookStatus.toRead => 'To Read',
    BookStatus.reading => 'Reading',
    BookStatus.read => 'Read',
    BookStatus.onHold => 'On Hold',
    BookStatus.dropped => 'Dropped',
  };
}

class BookQuote {
  const BookQuote({required this.id, required this.text, this.page});
  final String id;
  final String text;
  final int? page;
  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'page': page};
  factory BookQuote.fromJson(Map<String, dynamic> json) => BookQuote(
    id: json['id'] as String,
    text: json['text'] as String,
    page: json['page'] as int?,
  );
}

class Book {
  Book({
    required this.id,
    required this.title,
    this.author = '',
    this.coverImagePath,
    this.status = BookStatus.toRead,
    this.totalPages,
    List<ReadingSession> sessions = const [],
    this.subtitle = '',
    this.isbn = '',
    this.publisher = '',
    this.year,
    this.language = '',
    this.series = '',
    this.seriesNumber = '',
    List<String> tags = const [],
    this.notes = '',
    this.dropReason = '',
    this.format = BookFormat.paperback,
    this.totalMinutes,
    List<BookQuote> quotes = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) : sessions = List.unmodifiable(
         sessions.map(
           (s) => s.format != null
               ? s
               : s.copyWith(
                   format: format,
                   totalLength: format == BookFormat.audiobook
                       ? totalMinutes
                       : totalPages,
                   updatedAt: s.updatedAt,
                 ),
         ),
       ),
       tags = List.unmodifiable(tags),
       quotes = List.unmodifiable(quotes),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();
  final String id,
      title,
      author,
      subtitle,
      isbn,
      publisher,
      language,
      series,
      seriesNumber,
      notes,
      dropReason;
  final String? coverImagePath;
  final BookStatus status;
  final BookFormat format;
  final int? totalPages, totalMinutes, year;
  final List<ReadingSession> sessions;
  final List<String> tags;
  final List<BookQuote> quotes;
  final DateTime createdAt, updatedAt;
  final DateTime? deletedAt;
  BookFormat get currentFormat =>
      openSession?.format ?? sessions.lastOrNull?.format ?? format;
  bool get isAudio => currentFormat == BookFormat.audiobook;
  int? get progressTotal => openSession != null
      ? openSession!.totalLength
      : sessions.isNotEmpty
      ? sessions.last.totalLength
      : isAudio
      ? totalMinutes
      : totalPages;
  String get progressUnit => isAudio ? 'minutes' : 'pages';
  String progressLabel(int value) => isAudio
      ? '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}'
      : '$value';
  ReadingSession? get openSession =>
      sessions.where((s) => s.isOpen).firstOrNull;
  int get timesRead => sessions.where((s) => !s.isOpen).length;
  bool get isReread => timesRead > 1;
  DateTime? get lastFinished => sessions
      .where((s) => !s.isOpen)
      .map((s) => s.endDate!)
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  DateTime? get lastRead {
    DateTime? latest;
    for (final s in sessions) {
      final dates = [
        if (s.precision != DatePrecision.unknown) s.endDate ?? s.startDate,
        ...s.progress.map((p) => p.date),
      ];
      for (final date in dates) {
        if (latest == null || date.isAfter(latest)) latest = date;
      }
    }
    return latest;
  }

  double get progress => status == BookStatus.read
      ? 1
      : (progressTotal == null
            ? 0
            : ((openSession?.currentPage ?? 0) / progressTotal!).clamp(0, 1));
  double? get averageRating {
    final ratings = sessions
        .where((s) => s.rating != null)
        .map((s) => s.rating!)
        .toList();
    return ratings.isEmpty
        ? null
        : ratings.reduce((a, b) => a + b) / ratings.length;
  }

  Book copyWith({
    String? title,
    String? author,
    Object? coverImagePath = unset,
    BookStatus? status,
    Object? totalPages = unset,
    List<ReadingSession>? sessions,
    String? subtitle,
    String? isbn,
    String? publisher,
    Object? year = unset,
    String? language,
    String? series,
    String? seriesNumber,
    List<String>? tags,
    String? notes,
    String? dropReason,
    BookFormat? format,
    Object? totalMinutes = unset,
    List<BookQuote>? quotes,
    DateTime? updatedAt,
    Object? deletedAt = unset,
  }) => Book(
    id: id,
    title: title ?? this.title,
    author: author ?? this.author,
    coverImagePath: identical(coverImagePath, unset)
        ? this.coverImagePath
        : coverImagePath as String?,
    status: status ?? this.status,
    totalPages: identical(totalPages, unset)
        ? this.totalPages
        : totalPages as int?,
    sessions: sessions ?? this.sessions,
    subtitle: subtitle ?? this.subtitle,
    isbn: isbn ?? this.isbn,
    publisher: publisher ?? this.publisher,
    year: identical(year, unset) ? this.year : year as int?,
    language: language ?? this.language,
    series: series ?? this.series,
    seriesNumber: seriesNumber ?? this.seriesNumber,
    tags: tags ?? this.tags,
    notes: notes ?? this.notes,
    dropReason: dropReason ?? this.dropReason,
    format: format ?? this.format,
    totalMinutes: identical(totalMinutes, unset)
        ? this.totalMinutes
        : totalMinutes as int?,
    quotes: quotes ?? this.quotes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    deletedAt: identical(deletedAt, unset)
        ? this.deletedAt
        : deletedAt as DateTime?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'coverImagePath': coverImagePath,
    'status': status.name,
    'totalPages': totalPages,
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'subtitle': subtitle,
    'isbn': isbn,
    'publisher': publisher,
    'year': year,
    'language': language,
    'series': series,
    'seriesNumber': seriesNumber,
    'tags': tags,
    'notes': notes,
    'dropReason': dropReason,
    'format': format.name,
    'totalMinutes': totalMinutes,
    'quotes': quotes.map((q) => q.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String? ?? '',
    coverImagePath: json['coverImagePath'] as String?,
    status: BookStatus.values.byName(json['status'] as String? ?? 'toRead'),
    totalPages: json['totalPages'] as int?,
    sessions: (json['sessions'] as List<dynamic>? ?? [])
        .map((s) => ReadingSession.fromJson(s as Map<String, dynamic>))
        .toList(),
    subtitle: json['subtitle'] as String? ?? '',
    isbn: json['isbn'] as String? ?? '',
    publisher: json['publisher'] as String? ?? '',
    year: json['year'] as int?,
    language: json['language'] as String? ?? '',
    series: json['series'] as String? ?? '',
    seriesNumber: json['seriesNumber'] as String? ?? '',
    tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
    notes: json['notes'] as String? ?? '',
    dropReason: json['dropReason'] as String? ?? '',
    format: BookFormat.values.byName(json['format'] as String? ?? 'paperback'),
    totalMinutes: json['totalMinutes'] as int?,
    quotes: (json['quotes'] as List<dynamic>? ?? [])
        .map((q) => BookQuote.fromJson(q as Map<String, dynamic>))
        .toList(),
    createdAt: json['createdAt'] == null
        ? DateTime.utc(1970)
        : parseStoredDate(json['createdAt'] as String),
    updatedAt: json['updatedAt'] == null
        ? DateTime.utc(1970)
        : parseStoredDate(json['updatedAt'] as String),
    deletedAt: json['deletedAt'] == null
        ? null
        : parseStoredDate(json['deletedAt'] as String),
  );
}
