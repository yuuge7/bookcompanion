class ReadingSession {
  final String id;
  DateTime startDate;
  DateTime? endDate; // null while the book is currently being (re)read
  int? rating; // 1-5, optional, set when the session is finished
  int currentPage; // typed in directly, not incremented via +/-

  ReadingSession({
    required this.id,
    required this.startDate,
    this.endDate,
    this.rating,
    this.currentPage = 0,
  });

  bool get isOpen => endDate == null;

  int? get daysTaken =>
      endDate == null ? null : endDate!.difference(startDate).inDays + 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'rating': rating,
        'currentPage': currentPage,
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
    );
  }
}
