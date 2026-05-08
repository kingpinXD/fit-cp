# Fit - Fitness Tracking App

## Tech Stack
- **Language:** Dart 3.11+ (Flutter)
- **State management:** flutter_riverpod 3.x
- **Database:** Drift 2.x (SQLite, local-only)
- **Auth:** Firebase Auth + Google Sign-In
- **XLSX import:** `excel` + `archive` (hyperlinks read directly from the zip)
- **UI:** Material 3, dark by default
- **Theme:** Black and silver — backgrounds #0A0A0A / #1C1C1E, primary white, accents SuccessGreen #34C759, SkipBlue #5AC8FA, RpePurple #9C27B0, EquipmentGreen #2E7D32
- **Architecture:** Riverpod Notifier + StreamProvider chain. Repository owns SharedPreferences + Drift. UI is a thin Consumer.
- **Testing:** flutter_test, in-memory drift (`NativeDatabase.memory()`), `SharedPreferences.setMockInitialValues({})`.

## Build Commands
- `make build` — `flutter build apk --debug` → ~/Downloads/Fit.apk
- `make test` — flutter test (full suite)
- `make analyze` — flutter analyze
- `make run` — build + adb install + launch (debug, signed with the release keystore)
- `make install-phone` — build + install on every connected phone
- `make check-phone` — show installed version on connected phones
- `make release` — flutter build apk --release
- `make distribute NOTES="..."` — bump version, build release, push to Firebase App Distribution

## Environment
- `ANDROID_HOME=$HOME/android-sdk`
- JDK 17 (Homebrew OpenJDK)
- Flutter 3.41.x stable, Dart 3.11.x
- Package: `com.kingpinxd.fitcp`
- compileSdk = 36, targetSdk = 34, minSdk = 26

## Guidelines

### Multi-Device Awareness
- App may be installed on multiple phones. Any automatic logic (timers, scheduled resets) must be idempotent and safe to run on multiple devices simultaneously.
- Local SQLite (Drift) is the source of truth. Cloud export is just a JSON snapshot.

### Firebase Sync Lessons (from weekly-totals)
- **Never** spawn concurrent listeners that race on shared state. Serialize sync operations.
- Add a startup deduplication pass as a safety net for any imported data.
- Key cloud entries by a natural unique field (e.g., timestamp in millis) to prevent duplicates at the source.

### Testability
- Keep functions short and pure where possible.
- Inject `AppDatabase` and `SharedPreferences` via Riverpod overrides. The `ProgrammeRepository` accepts an `AssetLoader` so tests can substitute disk reads for `rootBundle`.
- Use `firstStream()` helper to drain a StreamProvider's first emission in tests — `.future` alone can stall.

### Code Style
- Early returns over nested if/else
- `final` over `var`, `const` constructors where possible
- Match the Flutter idioms in `float-coach` and `shopping-cart` for consistency
- DAO column names are kept camelCase via `case_from_dart_to_sql: preserve` in `build.yaml` so the raw SQL HAVING queries don't break

### XLSX quirks
The `excel` Dart package has two known crashes we work around in `XlsxParser`:
1. Absolute relationship targets (e.g. `Target="/xl/worksheets/sheet1.xml"`) — we strip them to relative.
2. Empty inline-string cells (`<c t="inlineStr"></c>`) — we inject `<is><t/></is>` so the parser can read the cell.
Both fixes happen in `_normalizeXlsxBytes` before handing bytes to the package.

### Decisions
- (2026-05-08) Kotlin → Flutter rewrite landed. Drift 2.x + Riverpod 3.x + Excel/archive for XLSX + Firebase Auth + Google Sign-In. Same applicationId `com.kingpinxd.fitcp`, same Firebase project, same release keystore — debug builds are also release-signed so SHA-1 matches in dev. The Kotlin-era Compose theme + sizing scale + accent palette ported as-is. iOS scaffold generated but not wired up.
- (2026-05-06) Migrating from Kotlin/Compose/Room to Flutter for cross-platform reach. Ship Android first, decide on iOS later.
