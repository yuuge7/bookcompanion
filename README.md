# Book Companion

A personal Android book tracker. Data lives on-device only — no accounts, no analytics, no network calls.

Inspired by [mangacompanion](https://github.com/yuuge7/mangacompanion), adapted for books: every read (and reread) is tracked as its own session with start/end dates, an optional per-read rating, and page progress.

## Features

- **To Read / Reading / Read / Dropped** tabs with live counts
- Reading tracked as a **list of sessions** — a reread adds a new entry instead of overwriting history, so the full read/reread timeline stays visible
- Start and end date per session, at a precision you choose: **exact** days,
  **approximate** (month only, and it may span months), or **unknown** — an old
  read with no remembered dates still counts, without a guessed day attached
- Optional 1–5 star rating per read (rate a reread differently from the first
  read), set when you finish, on the add/edit screen, or later from the book's
  reading history
- Page progress, typed in directly — no +/- stepper
- Light / dark / system theme, toggled from the app bar
- Stats screen: books read, pages read, completed reads, rereads, average rating
- Search by title or author
- Import/export as a plain JSON array

## Data model

```
Book
 ├─ title, author, coverImagePath, status, totalPages
 └─ sessions: [ReadingSession]
     ├─ startDate
     ├─ endDate    (null while the session is in progress)
     ├─ rating     (optional, 1–5)
     ├─ currentPage
     └─ precision  (exact | approximate | unknown)
```

`timesRead` is the number of sessions with an `endDate`. A book with `timesRead > 1` has been reread; every session's dates and rating stay visible on the book's detail screen.

`precision` says how far the dates can be trusted. `startDate` and `endDate` are always set, because `endDate == null` is what marks a read as still open — a finished read with no remembered dates still has to close. When `precision` is not `exact` the stored days are placeholders that the app never shows: only the month is displayed for `approximate`, and nothing at all for `unknown`, and `daysTaken` reports no duration rather than inventing one.

Exports written before `precision` existed load as `exact`, which is what they were — it was the only kind the app could record.

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Android Studio, or the Android SDK command-line tools with at least one platform installed
- A JDK 17+ (Android Studio bundles one)

### Setup

```bash
git clone <this-repo-url>
cd book_companion
flutter pub get
flutter run
```

### Project layout

```
lib/
 ├─ main.dart
 ├─ models/
 │   ├─ book.dart
 │   └─ reading_session.dart
 ├─ services/
 │   ├─ library_model.dart     # app state + session actions (start/finish/reread)
 │   ├─ storage_service.dart   # on-device JSON persistence + import/export
 │   └─ theme_notifier.dart    # light/dark/system toggle
 ├─ screens/
 │   ├─ home_screen.dart
 │   ├─ book_detail_screen.dart
 │   ├─ add_edit_book_screen.dart
 │   └─ stats_screen.dart
 └─ widgets/
     └─ book_card.dart
```

## Building a signed release APK locally

`android/app/build.gradle.kts` reads its signing config from `android/key.properties`, which is intentionally **not** committed (see `.gitignore`). To build a signed release on a machine that already has the signing key:

1. Place `book_companion_release.keystore` in the project root (next to `pubspec.yaml`).
2. Create `android/key.properties`:
   ```properties
   storePassword=<store password>
   keyPassword=<key password>
   keyAlias=upload
   storeFile=../../book_companion_release.keystore
   ```
3. Run:
   ```bash
   flutter build apk --release
   # APK at build/app/outputs/flutter-apk/app-release.apk
   ```

`android/app/build.gradle.kts` needs a signing block that reads that file — if it isn't there yet:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ...existing config...
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

## Signing key

Android requires every update to an installed app to be signed with the **same** key as the original install — a different key means uninstalling before you can reinstall. This project keeps a single signing key for its lifetime instead of generating a new one per machine:

- `book_companion_release.keystore` (RSA 2048, valid ~27 years) lives in the project root but is git-ignored — it is never committed, and never should be.
- Its passwords are not written down anywhere in this repo. Store them in a password manager or another secure vault you control.
- CI never touches the file itself — only a base64-encoded copy lives in encrypted GitHub Actions secrets, decoded fresh on every run (see the workflow below).

### Using the same key on another machine

1. Copy `book_companion_release.keystore` itself to the new machine (e.g. from your password manager's file storage, an encrypted USB drive, or another secure channel — not email, not a public repo, not chat).
2. Recreate `android/key.properties` there as shown above, using the same passwords.
3. That's it — builds from this machine will be signed identically to every other one, and Android will accept them as updates to an existing install.

If this key is ever lost, there's no way to recover it — any future release would need a new key, and everyone with the app installed would need to uninstall first.

## Releases

`.github/workflows/release.yml` runs on every push to `main` (skipping the version-bump commit it makes, so it doesn't loop) and:

1. Bumps the version in `pubspec.yaml` (`v1.0` → `v1.1` → `v1.2` …) and commits that back to `main`
2. Builds a signed release APK using the secrets below
3. Publishes a GitHub Release named `Book Companion vX.Y` with the APK attached

Before the first run, add these repository secrets (**Settings → Secrets and variables → Actions → New repository secret**):

| Secret | Value |
| --- | --- |
| `KEYSTORE_BASE64` | `base64 -w0 book_companion_release.keystore` (Linux/macOS), or `[Convert]::ToBase64String([IO.File]::ReadAllBytes("book_companion_release.keystore"))` (PowerShell) |
| `KEYSTORE_PASSWORD` | the store password |
| `KEY_PASSWORD` | the key password |
| `KEY_ALIAS` | `upload` |

## Contributing

1. Fork the repo and create a branch off `main`
2. Make your change — `flutter analyze` and `flutter test` should both pass
3. Open a pull request describing what changed and why

Small, focused PRs are easiest to review. New features that touch the data model (`Book`/`ReadingSession`) should keep existing JSON export/import working, since that's the only backup/migration path for someone's library today.

## License

MIT — see [LICENSE](LICENSE).