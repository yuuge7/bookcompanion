enum BookFormat { paperback, hardcover, ebook, audiobook }

extension BookFormatLabel on BookFormat {
  String get label => switch (this) {
    BookFormat.paperback => 'Paperback',
    BookFormat.hardcover => 'Hardcover',
    BookFormat.ebook => 'Ebook',
    BookFormat.audiobook => 'Audiobook',
  };
}
