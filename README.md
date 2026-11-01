# Book Companion

An offline Android reading journal. No accounts, analytics, telemetry, network
permission, or Android cloud backup. Your library stays in app storage until you
choose to export a file. Inspired by
[mangacompanion](https://github.com/yuuge7/mangacompanion).

## Reading

- Reading, To Read, Read, On Hold, and Dropped shelves, with live counts.
- Each read and reread has its own format, length, dates, date precision, rating,
  and progress. Choose paperback, hardcover, ebook, or audiobook when starting;
  edit an open read’s format or a completed read from its history entry.
  Exact, month-only, and unknown dates remain distinct. Unknown dates count in
  all-time totals without being assigned to a guessed year.
- Paperback, hardcover, ebook, and audiobook editions. Audio progress uses
  hours:minutes; it never adds listening minutes to page statistics.
- Optional subtitle, ISBN, publisher, publication year, language, series and
  number, tags/genres, personal notes, and a reason for dropping a book.
- Searchable quotes/highlights with optional page or listening-time location.
- Dated progress history, pace, estimated finish, and activity streaks.
- Accent-insensitive search with small typo tolerance across title, author,
  subtitle, ISBN, publisher, notes, series, tags, and quotes.
- Sort in either direction by title, author, date added, last read, last edited,
  rating, or progress. Last read follows reading dates and progress activity.
  Preview combined filters by tag, any read’s format, finish year, rating, and
  series before applying them. Clear filters or select All to remove them.
- Long-press a row to select books and change their shelf, tag, or trash them.
  Delete offers Undo; Settings → Trash can restore books for 30 days. Expired
  trash is removed on the next load/save. Unused managed covers are cleaned up.
- Camera/gallery covers with an on-device crop screen. Covers are compressed,
  stripped of EXIF/GPS, and copied into durable private storage.

## Backups and moving phones

Settings → Backups, import & export offers:

- **Complete `.bcbackup`**: a ZIP containing `library.json`, `covers/`, and
  `manifest.json`. The manifest records schema/app version, export time, book
  count, and SHA-256 checksums for the library and every cover. Includes trash.
- **Import preview**: added, changed, removed, and retained counts before writing.
  Merge matches IDs and keeps the newer `updatedAt`; a tie keeps the local copy.
  Replace explicitly confirms the current and incoming library sizes.
- **Recovery snapshots**: every import takes a complete local snapshot first.
  Daily snapshots are optional and on by default. The ten newest snapshots are
  retained and can be restored through the same preview, or exported.
- **Other formats**: schema-2 JSON, spreadsheet-safe CSV, printable HTML, and an
  offline-generated PDF. These exports omit image bytes; use `.bcbackup` to move
  covers. JSON exports from every past release remain readable. Goodreads CSV
  exports can also be imported, with deterministic IDs for repeat imports.

Invalid files, duplicate IDs, invalid dates, ratings outside 1–5, out-of-bounds
progress, unsafe ZIP paths, incomplete bundles, and checksum failures are rejected
before the library changes. JSON/CSV imports never follow arbitrary cover paths.
The previous unreadable raw library is preserved when a recovery import replaces
it. Snapshot files stay local, so export a backup before uninstalling the app.

The Android ID is now **`io.github.yuuge7.bookcompanion`**. If upgrading from
`com.example.book_companion`, export JSON in the old app before uninstalling it,
install the new app, then import. Android treats the IDs as separate apps. Old
JSON contains cover paths rather than photos: select those covers again, then
make a complete backup.

## Stats and settings

Stats supports a year selector and all-time totals, monthly books/pages charts,
rating distribution, top authors/tags, format split, listening time, reading
goals in books or pages, and progress-based streaks. Format totals count each
completed read; audio minutes and pages stay separate across mixed-format rereads.
Year in Review scrolls through the full card and keeps **Save image to phone**
visible above system navigation. It exports a PNG made on-device through the
phone’s folder picker and confirms a successful save. Historic reads without logs contribute known pages to their
finish month; daily activity comes only from real progress entries. Approximate
and unknown dates never invent daily streaks.

Settings persists light/dark/system theme, optional Android Material You colors,
default date precision, first day of week, backups, and privacy preferences.
App lock uses the device PIN/biometrics and covers the entire navigation stack on
launch and after backgrounding. Recent-apps hiding uses Android `FLAG_SECURE`
(also blocks screenshots/recording). App lock always enables that protection and
hides widget details. Exported files are not encrypted by the app lock.

Add the **Current book** Android home-screen widget from Settings or the launcher.
It shows the first book on your Reading shelf and a progress bar; tap to open its
progress editor. Android predictive back, edge-to-edge, and a themed icon are
enabled.

Library mutations are serialized and immutable. State changes only after a
flushed temporary file is renamed over the saved library. A failed save preserves
the previous state and offers retry/discard. Diagnostics contain only operation
names, error types, and counts, stay local, and can be exported from Settings.

## Development

Use Flutter **3.47.0**, Dart 3.10+, JDK 17+, and the Android SDK (compile API 37).

```sh
flutter pub get
flutter analyze
flutter test
flutter emulators --launch Medium_Phone
flutter test integration_test/app_test.dart -d emulator-5554
flutter run -d emulator-5554
```

Tests cover model round-trips/immutability, exports generated by the serializers
from tags v1.0–v1.5, validation, atomic persistence, save failure/retry, merge and
replace, covers/EXIF, snapshots, trash, search/filter/sort, stats math, settings,
CSV/HTML/PDF, large text, lock coverage, import confirmation, bulk actions, and the
add → start → page → finish → rate flow. The Android integration test also uses
real files, cropping, audio progress, cover bundles, native secure-window flags,
and restart persistence. It uses an isolated temporary library.

JSON remains the storage format. The suite includes a 5,000-book save/load check;
SQLite is reserved for demonstrated latency in a real large library. JSON stays
the import/export compatibility format either way.

## Releases

Pull requests run formatting, analysis, unit/widget tests, and an Android emulator
integration test. Main pushes run the same checks before the release job. A failed
check blocks release and the automatic version bump. Dependabot checks pub
dependencies weekly and GitHub Actions monthly.

The release job bumps the version, builds R8-minified APKs split by ABI, writes a
changelog from commit subjects, attaches `SHA256SUMS`, commits the successful
version bump, and publishes a GitHub Release. The bump commit skips CI to avoid a
loop. GitHub Actions needs `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`,
and `KEY_ALIAS` repository secrets.

For a signed local release, keep your existing `book_companion_release.keystore`
in the project root and create the ignored `android/key.properties`:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=../../book_companion_release.keystore
```

```sh
flutter build apk --release --split-per-abi
```

APKs appear in `build/app/outputs/flutter-apk/`. Without `key.properties`, local
release builds use the debug key for testing. Production releases must use the
existing release key. Keep the key and passwords in a secure backup; never commit
them. Losing the signing key prevents updating existing installations.

Generated builds, IDE caches, and local signing material are ignored. Source icon
art and `tool/make_icons.py` remain for reproducible launcher icons. PDF uses the
bundled Noto Sans font under its [SIL Open Font License](assets/fonts/OFL.txt).

MIT — see [LICENSE](LICENSE).
