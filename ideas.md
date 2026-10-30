# Ideas

What would take Book Companion from "nice personal app" to "polished, trustworthy, production-grade" — while staying offline, account-free, and file-based (import/export only).

Ordered by importance inside each section. Check items off as you go.

---

## 1. Fix first (found in the current code)

These are data-loss risks. A premium app never loses someone's library.

- [x] **Covers live in a temp cache.** `_pickCover` stores `picked.path` from `image_picker`, which points into the cache dir — Android can wipe it any time and every cover disappears. Copy the image into app storage (`<documents>/covers/<bookId>.jpg`) on save. ([add_edit_book_screen.dart:72](lib/screens/add_edit_book_screen.dart#L72))
- [x] **Saves aren't atomic.** `saveBooks` writes straight over `books.json`. A crash or dead battery mid-write corrupts the only copy. Write to `books.json.tmp`, flush, then rename over the original. ([storage_service.dart:51](lib/services/storage_service.dart#L51))
- [x] **Import wipes the library with no confirmation and no backup.** Show "Replace your 212 books with 180 from this file?" and take an automatic snapshot first. ([home_screen.dart:288](lib/screens/home_screen.dart#L288))
- [x] **Exports don't include covers.** `coverImagePath` points to a file on the old phone, so a restore on a new phone has no covers. See the backup bundle below.
- [x] **No version in the export format.** Wrap it: `{"app": "book_companion", "schemaVersion": 2, "exportedAt": "...", "books": [...]}`. Keep reading the old plain array.
- [x] **Theme choice resets on every launch.** `ThemeNotifier` is never saved.
- [x] **Application ID is still `com.example.book_companion`.** Change it to your own (e.g. `io.github.yuuge7.bookcompanion`). This makes it a different app to Android, so do it once, soon: export, install the new one, import.
- [x] **Google auto-backup is on by default.** Without `android:allowBackup="false"` (or `dataExtractionRules`), Android copies `books.json` to Google Drive — at odds with "data never leaves the device". Turn it off, or make it a setting.
- [x] **Build output is committed.** `android/build/` is tracked in git. Remove it and add it to `.gitignore`.
- [x] **CI releases every push without checks.** Run `flutter analyze` and `flutter test` first; fail the release if either fails.

---

## 2. Backup, import & export (the "no accounts" backbone)

Without accounts, files are the sync, backup and migration story, so this part has to be excellent.

- [x] **One backup file with everything:** `.bcbackup` = zip of `library.json` + `covers/` + `manifest.json` (schema version, app version, date, book count, SHA-256 checksum).
- [x] **Merge import** besides replace: match by `id`; on conflict the newer `updatedAt` wins, or ask.
- [x] **Import preview:** "+12 new, 3 changed, 0 removed" before anything is written.
- [x] **Strict validation with clear errors:** duplicate ids, end date before start date, rating outside 1–5, current page above total pages. Say which book is wrong, and never half-import.
- [x] **Add `createdAt` / `updatedAt`** to `Book` and `ReadingSession` (needed for merge and for sorting by date added).
- [x] **Export CSV** (opens in Excel/Sheets) and a printable **HTML/PDF reading list**.

---

## 3. Privacy & security

- [x] **Hide from recent-apps preview** (`FLAG_SECURE`), as a setting.
- [x] **Strip EXIF/GPS from cover photos** when copying them in — camera photos carry home location.

---

## 4. Library features

- [x] **Richer book fields:** subtitle, ISBN, publisher, year, language, series + number, tags/genres, personal notes. All optional. 
- [x] **Format:** paperback / hardcover / ebook / audiobook (audiobook progress in hours:minutes, not pages).
- [x] **Quotes & highlights** with page number, searchable.
- [x] **Progress log:** store `{date, page}` each time the page changes, instead of only the latest page. Unlocks pace, streaks, finish-date predictions and per-day stats.
- [x] **On Hold** status, separate from Dropped. Optional "why I dropped it" note.
- [x] **Sorting:** title, author, date added, last read, rating, progress. **Filters:** tag, format, year finished, rating, series.
- [x] **Bulk actions:** multi-select to change status, tag or delete.
- [x] **Undo + trash:** delete shows "Undo" and moves to a 30-day trash instead of vanishing.
- [x] **Cover from camera** with crop.
- [x] **Android home-screen widget:** current book + progress bar, tap to update page.

---

## 5. Stats & insights

- [x] **Year selector** for all stats.
- [x] **Charts:** books and pages per month, rating distribution, top authors and tags, format split.
- [x] **Pace:** pages per day, estimated finish date for the current book.
- [x] **Reading goal:** yearly target (books or pages) with on-track / behind.
- [x] **Streaks** (needs the progress log).
- [x] **Year in Review** screen, exportable as an image made on-device.

---

## 6. Polish & UX

- [x] **Settings screen:** theme, app lock, backups, default date precision, first day of week.
- [x] **Search:** ignore accents (`é` = `e`), allow typos, also search notes, tags, series and quotes.
- [x] **Motion:** Hero cover transition list → detail, light haptics on finish/rate.
- [x] **Android 14+:** predictive back, edge-to-edge, themed (monochrome) icon — the icon is already done.
- [x] Optional **Material You** dynamic color, next to the custom theme.
- [x] **Empty states** that teach: first launch, empty tab, no search results, first import.

---

## 7. Engineering quality

- [x] **Tests** (today there's one smoke test):
  - JSON round-trip for every model.
  - **Old-export fixtures:** keep a sample file from every past version in `test/fixtures/` and assert it still imports. This is your compatibility promise.
  - `LibraryModel` actions (start, finish, reread, drop, edit session) and stats math.
  - Widget tests for add → start → set page → finish → rate.
  - One integration test on an emulator in CI.
- [x] **Immutable models** (`copyWith`, or `freezed`). Today edits change objects in place before saving, so a failed save leaves memory and disk out of sync.
- [x] **Handle save failures** (disk full, permission): keep state, show a banner, retry.
- [x] **Local-only error log** + "Export diagnostics" button in Settings. No Crashlytics, no telemetry.
- [x] **Stricter lints** (`very_good_analysis` or extra rules in `analysis_options.yaml`).
- [x] **Dependency updates** via Dependabot or Renovate.
- [x] **Smaller APK:** R8/minify, `--split-per-abi`, compress cover images on import.
- [x] Consider SQLite (`drift`) only if the library grows into thousands of books and saving feels slow. Keep JSON as the export format regardless.

---

## 8. Releases without app stores

- [x] **Changelog** in each GitHub Release, generated from commit messages.
- [x] **SHA-256 checksum** attached next to each APK.

---

## Suggested order

1. Everything in **Fix first**.
2. Backup bundle + auto snapshots + merge import (section 2, first five items).
3. Tests with old-export fixtures + CI gates.
4. App lock, settings screen, undo/trash.
5. Progress log, richer fields, Goodreads import.
6. Stats, widget, polish.

## Implementation and verification — 2026-10-30

All 50 checklist items have been handled. The source references in the original
findings describe the code before these changes.

- `flutter analyze`: clean; formatting and diff whitespace checks pass.
- `flutter test`: 41 passing tests, including exports serialized by v1.0–v1.5.
- Android 17 / API 37 emulator integration: passed with real persistence,
  image cropping, audiobook progress, trash restore, backup merge and native
  secure-window flag checks.
- Installed minified release: tested native JSON import, complete backup export
  (manifest version/count/checksums verified), PDF export/render, Year in Review
  PNG export/render, launcher widget pin/tap/page update, and device-PIN app lock
  enable/unlock/background relock/disable. Temporary PIN and test data removed.
- All three split-ABI release APKs build and their signatures verify. The release
  manifest has no network permission and disables Android backup.
- GitHub CI/release and Dependabot workflows are configured and syntax-checked;
  the remote GitHub jobs have not been triggered from this workspace.
- SQLite was considered. The 5,000-book JSON save/load test passes; retain JSON
  until profiling a real large library on-device demonstrates a need to migrate.
- Build output, temporary QA artifacts and IDE caches are removed from the repo.