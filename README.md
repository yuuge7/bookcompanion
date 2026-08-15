# Book Companion

Personal Android book tracker. Data lives on-device only. Inspired by
[mangacompanion](https://github.com/yuuge7/mangacompanion), adapted for books
with per-read start/end dates and full reread history.

## Features

- To Read / Reading / Read / Dropped tabs with live counts
- Per-book cover image, author, status
- Reading tracked as a **list of sessions** — each start/finish is one
  session, so rereads simply add another entry instead of overwriting history
- Optional 1–5 star rating per read (so you can rate a reread differently
  from the first read)
- Stats screen: books read, total completed reads, reread count, average
  rating
- Search by title/author
- Import/Export: plain JSON array, same philosophy as mangacompanion

## Data model

```
Book
 ├─ title, author, coverImagePath, status
 └─ sessions: [ReadingSession]
     ├─ startDate
     ├─ endDate (null while in progress)
     └─ rating (optional, set on finish)
```

`timesRead` = number of sessions with an `endDate`. A book with `timesRead > 1`
has been reread; its full history (every start/end pair and rating) stays
visible on the book detail screen.

## Setup

This project was written outside of a Flutter environment, so dependencies
haven't been fetched or verified against a live SDK yet. On a machine with
Flutter installed:

```bash
flutter create --org com.example --platforms android .   # generates android/ etc. if missing
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
# APK at build/app/outputs/flutter-apk/app-release.apk
```

## Project layout

```
lib/
 ├─ main.dart
 ├─ models/
 │   ├─ book.dart
 │   └─ reading_session.dart
 ├─ services/
 │   ├─ library_model.dart     # app state + session actions (start/finish/reread)
 │   └─ storage_service.dart   # on-device JSON persistence + import/export
 ├─ screens/
 │   ├─ home_screen.dart
 │   ├─ book_detail_screen.dart
 │   ├─ add_edit_book_screen.dart
 │   └─ stats_screen.dart
 └─ widgets/
     └─ book_card.dart
```

## Notes / next steps

- No automated tests yet (mangacompanion has export round-trip tests worth
  copying the pattern of).
- No page-count/progress-bar tracking yet — only dates. Could add a
  `currentPage`/`totalPages` pair to `ReadingSession` if you want that back.
- Cover images are stored as local file paths (from the gallery); no
  cropping/resizing beyond `image_picker`'s `maxWidth`.
