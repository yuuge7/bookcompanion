/// How much of a read's dates is actually known.
///
/// A book finished years ago often has no exact days attached to it, and
/// inventing one is worse than admitting it. [approximate] keeps the month
/// and year only; [unknown] keeps neither.
enum DatePrecision { exact, approximate, unknown }

extension DatePrecisionLabel on DatePrecision {
  String get label => switch (this) {
        DatePrecision.exact => 'Exact',
        DatePrecision.approximate => 'Approximate',
        DatePrecision.unknown => 'Unknown',
      };
}

class ReadingSession {
  final String id;
  DateTime startDate;
  DateTime? endDate; // null while the book is currently being (re)read
  int? rating; // 1-5, optional
  int currentPage; // typed in directly, not incremented via +/-

  /// How far the dates on this read can be trusted.
  ///
  /// [startDate] and [endDate] stay set whatever this says, because
  /// `endDate == null` is what marks a read as still open — a finished read
  /// with no remembered dates still has to close. When this is not
  /// [DatePrecision.exact] the stored days are placeholders and the app
  /// never shows them; only the month is shown for
  /// [DatePrecision.approximate], and nothing at all for
  /// [DatePrecision.unknown].
  DatePrecision precision;

  ReadingSession({
    required this.id,
    required this.startDate,
    this.endDate,
    this.rating,
    this.currentPage = 0,
    this.precision = DatePrecision.exact,
  });

  bool get isOpen => endDate == null;

  /// Only meaningful when the days themselves are. An approximate or
  /// unknown read reports no duration rather than a made-up one.
  int? get daysTaken => endDate == null || precision != DatePrecision.exact
      ? null
      : endDate!.difference(startDate).inDays + 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'rating': rating,
        'currentPage': currentPage,
        'precision': precision.name,
      };

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      id: json['id'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      rating: json['rating'] as int?,
      currentPage: json['currentPage'] as int? ?? 0,
      // Exports written before precision existed have exact dates by
      // definition — that was the only kind the app could record.
      precision: DatePrecision.values.firstWhere(
        (p) => p.name == json['precision'],
        orElse: () => DatePrecision.exact,
      ),
    );
  }
}
