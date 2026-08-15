import 'reading_session.dart';

enum BookStatus { toRead, reading, read, dropped }

extension BookStatusLabel on BookStatus {
  String get label {
    switch (this) {
      case BookStatus.toRead:
        return 'To Read';
      case BookStatus.reading:
        return 'Reading';
      case BookStatus.read:
        return 'Read';
      case BookStatus.dropped:
        return 'Dropped';
    }
  }
}

class Book {
  final String id;
  String title;
  String author;
  String? coverImagePath; // local file path, mirrors mangacompanion's cover handling
  BookStatus status;
  int? totalPages; // optional — lets progress show as a fraction/percent
  List<ReadingSession> sessions;

  Book({
    required this.id,
    required this.title,
    required this.author,
    this.coverImagePath,
    this.status = BookStatus.toRead,
    this.totalPages,
    List<ReadingSession>? sessions,
  }) : sessions = sessions ?? [];

  /// The session currently in progress, if any (this read or a reread).
  ReadingSession? get openSession =>
      sessions.where((s) => s.isOpen).cast<ReadingSession?>().firstOrNull;

  /// Number of completed reads, including rereads.
  int get timesRead => sessions.where((s) => !s.isOpen).length;

  bool get isReread => timesRead > 1;

  DateTime? get lastFinished {
    final finished = sessions.where((s) => s.endDate != null).toList()
      ..sort((a, b) => b.endDate!.compareTo(a.endDate!));
    return finished.isEmpty ? null : finished.first.endDate;
  }

  /// Average rating across every completed session that has one.
  double? get averageRating {
    final rated = sessions.where((s) => s.rating != null).toList();
    if (rated.isEmpty) return null;
    return rated.map((s) => s.rating!).reduce((a, b) => a + b) / rated.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'coverImagePath': coverImagePath,
        'status': status.name,
        'totalPages': totalPages,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String? ?? '',
      coverImagePath: json['coverImagePath'] as String?,
      status: BookStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BookStatus.toRead,
      ),
      totalPages: json['totalPages'] as int?,
      sessions: (json['sessions'] as List<dynamic>? ?? [])
          .map((s) => ReadingSession.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
