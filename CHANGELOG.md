# Changelog

All notable changes to this project will be documented in this file.

## [0.7.0] - 2026-03-25

### Added

- **Multi-method shard input** (Web app): New `ShardInput` component replaces the bare `qrcode-stream` on both Combine and Print pages. Three shard entry modes — camera (default, existing), upload image (multi-file, decodes via `jsqr`), and paste text (multi-line JSON). Includes inline feedback with auto-clear timer. Camera mirror CSS scoped to component. New `src/util/qrDecode.ts` helper for image-to-text QR decoding. 11 new i18n keys across all 6 locales.
- **Paste text mode** (Flutter): `ShardScanner` widget gains a "Paste text" mode alongside the existing camera and gallery import. Users can paste one or more JSON shard strings (one per line) and submit. Summary SnackBar reports added/failed/duplicate counts. Mode switching disposes/reinits camera to save resources. 8 new i18n keys across all 6 locales.

### Changed

- **`ShardScanner.onScanned` callback** (Flutter): Changed from `void Function(String)` to `ShardError? Function(String, {bool isBatch})`. Enables paste mode to collect per-line results and build summary feedback. Fixes pre-existing issue where shards rejected by `RestoreNotifier` were still added to `_seenCodes` dedup set. Gallery import now correctly classifies duplicates vs failures using the returned error.

## [0.6.4] - 2026-03-22

### Fixed

- **Android file sharing** (Flutter): Telegram (and other strict apps) disabled the send button when receiving shared files from Banana Split. Root cause: `Share.shareXFiles` calls omitted MIME types, so Android's `ContentResolver` reported `application/octet-stream` — Telegram couldn't validate the content and refused to send. Fixed by specifying explicit MIME types (`image/png` for QR shards, `application/pdf` for documents) on all three share paths: single shard, batch PNGs, and Files tab.
- **Android share target visibility** (Flutter): Added `SEND` and `SEND_MULTIPLE` intent queries to `AndroidManifest.xml`. On Android 11+ (API 30+), package visibility filtering could hide valid share targets unless the app declares which intent actions it uses.

## [0.6.3] - 2026-03-20

### Changed

- **New app icon**: Replaced dark, low-contrast icon with new clean Banana Split logo (bright, white background, two bananas splitting with QR code). Updated across all platforms — Android (mipmap + adaptive foreground, 5 densities), Windows (multi-size ICO), macOS (7 AppIcon sizes), and Flutter assets. Web app retains banana emoji favicon.
- Added `flutter_launcher_icons` as dev dependency for reproducible icon generation. Future icon changes: replace `assets/app_icon.png`, run `dart run flutter_launcher_icons`.

## [0.6.2] - 2026-03-20

### Fixed

- **QR codes with non-Latin titles** (Flutter): Cyrillic, Georgian, and other Unicode titles produced QR codes with corrupted finder patterns (anchor squares). Root cause: `qr_flutter`'s pixel-size rounding could push the QR image beyond its container at certain module counts. Fixed by pre-computing the QR module count and sizing the render area to an exact integer multiple. Affects Windows and Android.
- **Shard count validation** (Web app): Typing invalid values (e.g. 1/1) into the total shards or quorum fields bypassed HTML `min`/`max` attributes and crashed Shamir's algorithm. Added client-side validation with inline error message and disabled Generate button. Localized in all 6 languages.

### Added

- 16 new QR render-size tests covering all 6 app languages, emoji, CJK, Arabic, overflow regression proof, and all 40 QR versions.

## [0.6.1] - 2026-03-19

### Added

- **Save format picker**: "Save all shards" button now opens a menu with two options — "Save as PDF" (multi-page document with passphrase placeholder) or "Save as PNGs" (individual QR images in a named folder). Localized in all 6 languages.

### Fixed

- Bulk gallery import now processes all selected files. Previous version only imported the first file due to a 500ms scan throttle designed for live camera deduplication.

## [0.6.0] - 2026-03-19

### Added

- **Bulk gallery import**: "Import from gallery" now supports multi-file selection. Select all shard PNGs at once instead of one by one. Uses `FilePicker` (Windows) with `allowMultiple` and `ImagePicker.pickMultiImage` (mobile). Shows summary snackbar ("X imported, Y failed") for partial failures. Localized in all 6 languages.

### Fixed

- **QR code export quality**: Exported QR PNGs and PDFs rendered at 800px (was 300px) with 8% quiet zone (white border). Eliminates fractional module sizes that damaged finder patterns at low resolution — QR codes are now crisp and reliably scannable on all platforms.
- Unicode secret titles (Cyrillic, Georgian, etc.) now create proper named folders and files. Previous regex stripped all non-ASCII characters.

## [0.5.6] - 2026-03-19

### Fixed

- QR code export quality: rendered at 800px (was 300px) to eliminate fractional module sizes that damaged finder patterns. Both PNG and PDF exports now produce crisp, reliably scannable QR codes.

## [0.5.5] - 2026-03-19

### Fixed

- Unicode secret titles (Cyrillic, Georgian, etc.) now create proper named folders and files. Previous regex `[^\w\s-]` stripped all non-ASCII characters, causing files like `_shard_1.png` in the root `banana_split/` directory. Now only filesystem-unsafe characters (`/\:*?"<>|`) are stripped.

## [0.5.4] - 2026-03-19

### Fixed

- Exported QR PNGs now include a quiet zone (10% white border on each side). QR spec requires a margin around finder patterns for reliable scanning. Affects all platforms (Android, Windows, macOS, Linux) — PNGs, PDFs, and shared files.

## [0.5.3] - 2026-03-19

### Fixed

- Windows: Camera auto-recovers after file picker dialogs and tab switches. `_isPickingFile` guard prevents false lifecycle disposal. `_cameraInitialized` flag enables smart reinit.
- Windows: Manual "Retry camera" button in the "Camera not available" state (localized in all 6 languages).
- Windows: QR PNG export rendered with white background instead of transparent — fixes "No QR found in image" when re-importing saved PNGs. Root cause: `QrPainter.toImage()` produces transparent background, which Windows viewers render as black-on-black.
- Windows: File picker now opens in `banana_split/` documents directory (switched from `ImagePicker` to `FilePicker` on Windows for `initialDirectory` support).
- Windows: `DecodeHintType.tryHarder` added to zxing2 QR decode for more robust detection.

## [0.5.2] - 2026-03-19

### Added

- **Web app internationalization**: Full i18n support using vue-i18n v8 with 6 languages — English, Russian, Turkish, Belarusian, Georgian, Ukrainian. All UI strings extracted to JSON locale files (55 keys each). Browser language auto-detected on each visit (no persistence). Slavic languages use custom pluralization rules for 3-form plurals (one|few|many).
- **Language selector in web app**: Flag-based dropdown in the header for switching the app language.
- **Independent print language**: Print language can be selected separately from the app language via a flag dropdown next to the Print button on the Share view. Shard QR code labels render in the selected print language.
- **Windows live camera scanning**: Camera-based QR scanning on Windows using the `camera` package (`camera_windows`) with periodic `takePicture()` + `zxing2` decode. Shows live camera preview and scans for QR codes every 800ms. Android/iOS continue using `mobile_scanner`.
- **Responsive QR grid**: QR shard cards dynamically adapt columns (1-4) and sizing based on window width using `LayoutBuilder`. Cards scale between 160-240px. Resizes live when the window is dragged on desktop.
- **Web app favicon**: Banana emoji (🍌) as inline SVG favicon, works in the self-contained single HTML file.

### Fixed

- CSS: Global `input { width: 100% }` no longer affects checkboxes — reset to native sizing.
- CSS: "Use custom passphrase" label aligned right under the refresh button with correct font size.
- Build: Replaced optional chaining (`?.`) with ternary for ES2015 target compatibility.
- Build: `git describe --tags` flag added so lightweight tags are recognized for the version footer.
- Windows: Gallery QR import ("No QR found in image") — normalized pixel values to 0-255 range for all image bit depths.
- Windows: Window title set to "Banana Split" (was "banana_split_flutter").
- Windows: Custom app icon (6 sizes: 16-256px) replacing default Flutter icon.
- Windows: Executable renamed to `banana_split.exe` with updated version info and `launch.bat`.

## [0.5.0] - 2026-03-18

### Added

- **v2 shard support in web app**: Web app can now reconstruct v2 shards generated by the Flutter app. v2 uses the same encoding as v1 (base64 nonce + base64 shard data). Full cross-app interoperability — shards from either app work in either app.
- **Custom passphrase in web app**: Share view now supports manual passphrase entry (min 8 characters) alongside auto-generated 4-word passphrases. Toggle via "Use custom passphrase" checkbox. Both apps now have feature parity on passphrase input.
- **Selectable quorum in web app**: Users can now choose how many shards are required to reconstruct (range 2 to total). Defaults to majority (`floor(total/2) + 1`) and resets on total change. Both apps now have feature parity on quorum selection.
- **PDF Unicode fonts in Flutter app**: Bundled Roboto (Regular + Bold) for Latin/Cyrillic/Turkish and Noto Sans Georgian for Georgian locale. PDF exports now render correctly in all 6 supported languages. Font selected by app locale.
- **Language selector**: Flag-based locale picker in the AppBar on every screen. Switches language immediately. Choice persisted via `SharedPreferences` across app restarts. 6 languages: English, Russian, Turkish, Belarusian, Georgian, Ukrainian.
- **Files tab**: 4th tab in bottom navigation for browsing, sharing, and deleting saved PDFs and PNGs. Scans `banana_split/` directory recursively, shows file size and date, supports pull-to-refresh. Auto-refreshes when tab is selected or app is resumed.
- **App icon**: Custom Banana Split logo for Android (adaptive icon with white background, all mipmap densities) and Windows (ICO). Android app label changed to "Banana Split".
- **Web app S3 support**: Removed offline-only enforcement, local file protocol check, and IPFS integrity hash. The web app now works from any origin — S3 static hosting, any web server, or local file.
- **Web build in release workflow**: Release workflow now builds the self-contained HTML file alongside Android and Windows artifacts, all attached to GitHub Releases with checksums.
- **Widget tests**: Tests for `FilesScreen` (empty state, file listing, delete confirmation) and `LanguageSelectorButton` (flag display, dropdown, locale switching). 56 total tests.

### Changed

- Release workflow renamed from `flutter-release.yml` to `release.yml` — now covers all platforms (Android, Windows, Web).
- License page icon updated from generic security icon to Banana Split logo.
- README fully rewritten with downloads table, architecture overview, dev setup, CI/CD docs, S3 deployment guide, and shard compatibility matrix.

### Fixed

- Files tab now refreshes on tab selection (`IndexedStack` builds all tabs at startup, so `initState` alone missed files saved after launch).
- Locale matching in language selector normalized to avoid `Locale('en', 'US') != Locale('en')` mismatch with `PopupMenuButton.initialValue`.
- Duplicate Android resource `ic_launcher_background` between `ic_launcher_background.xml` and `colors.xml`.
- Web app build: restored `vm` type declaration in `vue.d.ts` needed by `ShardInfo.vue` print portal.

## [0.4.0] - 2026-03-17

### Added

- **About screen enhancements**: Version display (via `package_info_plus`), Privacy Policy page (inline + "View online" link to GitHub), Open-source licenses page (Flutter built-in `showLicensePage` with GPLv3 registered).
- **Privacy Policy**: `PRIVACY_POLICY.md` at repo root; in-app screen with localized text.
- **App localization**: 6 languages — English, Russian, Turkish, Belarusian, Georgian, Ukrainian. Uses Flutter's official `flutter_localizations` with ARB files and code generation.
- **Typed error handling**: `ShardError` sealed class hierarchy in `restore_notifier.dart` replaces string-based errors. Enables localized error messages via exhaustive `switch` in the UI layer.
- **Unit tests**: 5 new tests for `ShardError` handling in `restore_notifier_test.dart` (41 total).

### Changed

- All hardcoded UI strings replaced with `AppLocalizations` calls across all screens, widgets, and services.
- Navigation labels refactored from `static const` to runtime-built (localization requires `BuildContext`).
- `ExportService.saveAsPdf` now accepts localized string parameters instead of hardcoded English text.

## [0.3.2] - 2026-03-17

### Added

- **CI/CD workflows**: Flutter CI (analyze, test, on-demand debug builds) and Flutter Release (Android APK/AAB + Windows zip, GitHub Release with SHA-256 checksums). Triggered by tag push or manual dispatch.
- **Consolidated web app CI**: Merged yarn tests, E2E tests, CodeQL, and Trivy scan into single `web-ci.yml` with path filtering to skip Flutter-only changes.
- **Windows launcher** (`launch.bat`): Checks for Visual C++ Runtime and offers to download/install the redistributable if missing.
- **zxing2 QR fallback**: Gallery image import now decodes QR codes via pure Dart `zxing2` library when `mobile_scanner.analyzeImage()` is unavailable (fixes Windows/Linux gallery import).
- **Camera on all platforms**: Removed hard-coded skip of camera init on Windows/Linux. Camera now attempts to start on all platforms with graceful fallback.
- **Android lifecycle handling**: `WidgetsBindingObserver` disposes camera on app background and re-initializes on resume. `_disposed` flag prevents use-after-dispose crashes in async callbacks.

### Fixed

- **`vue.config.js`**: `git describe --long` now falls back to `git rev-parse --short HEAD` when no tags exist, fixing CI failures.
- **E2E workflow**: Install Playwright browsers + ffmpeg for E2E tests.
- **Windows builds**: Use release mode (not debug) to avoid dependency on non-redistributable debug CRT DLLs.

## [0.3.1] - 2026-03-17

### Added

- **Flutter app** (`banana_split_flutter/`): Full port of Banana Split to Flutter targeting Android and desktop (Windows/macOS/Linux).
- **Shamir's Secret Sharing**: Pure Dart port of `secrets.js-grempe` GF(256) arithmetic — log/exp tables, Horner's method, Lagrange interpolation.
- **Crypto pipeline**: scrypt key derivation (N=32768, r=8, p=1, dkLen=32) + NaCl secretbox (XSalsa20-Poly1305) via `pinenacl` TweetNaCl API, with SHA-512 salt derivation from title.
- **Shard model**: Support for reading v0 (legacy hex), v1 (current web app base64), and v2 (Flutter) shard formats. Writes v2 only.
- **Passphrase generator**: 4-word auto-generated passphrases from 7776-word list, with manual entry toggle (min 8 characters).
- **Create flow**: Two-step wizard — input form (title, secret, shard count) then results view with QR grid, passphrase display, and export options.
- **Restore flow**: Camera QR scanning via `mobile_scanner`, gallery image import, batch scanning with progress indicator, passphrase input with normalization, and secret display.
- **Export service**: Save shards as individual PNGs or multi-page PDF (with passphrase reminder per page), share via OS share sheet.
- **State management**: `ChangeNotifier` + `Provider` with `CreateNotifier` and `RestoreNotifier`.
- **Isolate support**: Heavy crypto operations (`share`, `reconstruct`) run in `Isolate.run()` to keep the UI responsive.
- **Test suite**: 42 tests across 6 files — Shamir, Shard model, crypto round-trip, passphrase generation, integration, and widget tests.
- **Test runner**: `tests/run_all.sh` wrapper using JSON reporter with Python3 parser for clean CLI output.
- **Design spec and implementation plan** in `docs/superpowers/`.
