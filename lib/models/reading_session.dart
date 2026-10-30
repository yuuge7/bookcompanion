enum DatePrecision { exact, approximate, unknown }

extension DatePrecisionLabel on DatePrecision {
  String get label => switch (this) {
    DatePrecision.exact => 'Exact',
    DatePrecision.approximate => 'Approximate',
    DatePrecision.unknown => 'Unknown',
  };
}

const unset = Object();

DateTime parseStoredDate(String value) {
  final date = DateTime.parse(value);
  final prefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (prefix == null ||
      int.parse(prefix[2]!) < 1 ||
      int.parse(prefix[2]!) > 12 ||
      int.parse(prefix[3]!) < 1 ||
      int.parse(prefix[3]!) >
          DateTime(int.parse(prefix[1]!), int.parse(prefix[2]!) + 1, 0).day) {
    throw const FormatException('Invalid calendar date');
  }
  return date;
}

class ProgressEntry {
  const ProgressEntry({required this.date, required this.page, this.fromPage});
  final DateTime date;

  /// Minutes for audiobooks, pages for other formats.
  final int page;
  final int? fromPage;
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'page': page,
    'fromPage': fromPage,
  };
  factory ProgressEntry.fromJson(Map<String, dynamic> json) => ProgressEntry(
    date: parseStoredDate(json['date'] as String),
    page: json['page'] as int,
    fromPage: json['fromPage'] as int?,
  );
}

class ReadingSession {
  ReadingSession({
    required this.id,
    required this.startDate,
    this.endDate,
    this.rating,
    this.currentPage = 0,
    this.precision = DatePrecision.exact,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProgressEntry> progress = const [],
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now(),
       progress = List.unmodifiable(progress);
  final String id;
  final DateTime startDate;
  final DateTime? endDate;
  final int? rating;
  final int currentPage;
  final DatePrecision precision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProgressEntry> progress;
  bool get isOpen => endDate == null;
  int? get daysTaken => endDate == null || precision != DatePrecision.exact
      ? null
      : DateTime.utc(endDate!.year, endDate!.month, endDate!.day)
                .difference(
                  DateTime.utc(startDate.year, startDate.month, startDate.day),
                )
                .inDays +
            1;
  ReadingSession copyWith({
    DateTime? startDate,
    Object? endDate = unset,
    Object? rating = unset,
    int? currentPage,
    DatePrecision? precision,
    DateTime? updatedAt,
    List<ProgressEntry>? progress,
  }) => ReadingSession(
    id: id,
    startDate: startDate ?? this.startDate,
    endDate: identical(endDate, unset) ? this.endDate : endDate as DateTime?,
    rating: identical(rating, unset) ? this.rating : rating as int?,
    currentPage: currentPage ?? this.currentPage,
    precision: precision ?? this.precision,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    progress: progress ?? this.progress,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'rating': rating,
    'currentPage': currentPage,
    'precision': precision.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'progress': progress.map((p) => p.toJson()).toList(),
  };
  factory ReadingSession.fromJson(Map<String, dynamic> json) => ReadingSession(
    id: json['id'] as String,
    startDate: parseStoredDate(json['startDate'] as String),
    endDate: json['endDate'] == null
        ? null
        : parseStoredDate(json['endDate'] as String),
    rating: json['rating'] as int?,
    currentPage: json['currentPage'] as int? ?? 0,
    precision: DatePrecision.values.byName(
      json['precision'] as String? ?? 'exact',
    ),
    createdAt: json['createdAt'] == null
        ? parseStoredDate(json['startDate'] as String)
        : parseStoredDate(json['createdAt'] as String),
    updatedAt: json['updatedAt'] == null
        ? parseStoredDate((json['endDate'] ?? json['startDate']) as String)
        : parseStoredDate(json['updatedAt'] as String),
    progress: (json['progress'] as List<dynamic>? ?? [])
        .map((p) => ProgressEntry.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}
