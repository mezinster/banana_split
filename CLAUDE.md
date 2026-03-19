# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Banana Split is a Vue 2 + TypeScript web app that uses Shamir's Secret Sharing to split secrets (e.g., paper backups) into N QR-code shards, requiring a user-configurable quorum to reconstruct. It builds to a **single self-contained HTML file** (all JS/CSS inlined) that can be deployed to S3, any web server, or opened locally as a file.

## Environment Setup

Requires Node.js v14 (see `.nvmrc`) and Yarn. Use nvm to manage Node versions:

```bash
# Install nvm (if not already installed)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# In a new terminal (or source ~/.bashrc), then:
nvm install 14          # Installs Node v14.x (matches .nvmrc)
npm install -g yarn     # Install Yarn globally
yarn install            # Install project dependencies
```

nvm is a bash function, not a binary — it requires `source "$NVM_DIR/nvm.sh"` before use. In non-interactive or tool shells (e.g., Claude Code Bash tool), source it explicitly each time:
```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && yarn test:unit
```

## Commands

- **Dev server:** `yarn serve`
- **Build:** `yarn build` (produces self-contained HTML in `dist/`)
- **Lint:** `yarn lint` (ESLint with vue, prettier, and security plugins)
- **Unit tests:** `yarn test:unit` (Jest, tests in `tests/unit/`)
- **Run single unit test:** `yarn test:unit --testPathPattern=<pattern>`
- **E2E tests:** `yarn test:e2e` (Playwright with Chromium, auto-starts dev server on port 8888)

## Architecture

**Crypto pipeline** (`src/util/crypto.ts`): Core logic — encrypts secret with scrypt-derived key + NaCl secretbox, then splits ciphertext via `secrets.js-grempe` (Shamir). Supports v0 (hex-encoded nonces) and v1 (base64-encoded nonces/shards) formats. Exports `share()`, `parse()`, `reconstruct()`.

**Views** (`src/views/`): Four routes — Info (landing), Share (split a secret), Print (QR code printout), Combine (scan QR codes to reconstruct).

**Build** (`vue.config.js`): Uses `html-webpack-inline-source-plugin` to inline all assets into a single HTML file. Injects git revision via `DefinePlugin`.

**Localization** (`src/i18n.ts`, `src/locales/`): vue-i18n v8 with 6 locales (EN, RU, TR, BE, KA, UK) in JSON files. Browser language auto-detected on each visit (no persistence). Slavic languages (RU, UK, BE) use custom `pluralizationRules` for 3-form plurals (one|few|many). Print language is independently selectable via `printLocale` on Share.vue, passed through ShardInfo → ShardQrCode using `$t(key, locale)` 3-arg form. ShardInfo's detached Vue instance for print rendering requires explicit `i18n` injection (`new Vue({ el, i18n, render })`). All new UI strings must be added to `src/locales/en.json` (template) and all 5 translation files.

## Key Conventions

- Path alias `@/` maps to `src/` (configured in jest and webpack)
- ESLint security plugin is active — `detect-object-injection` and `detect-non-literal-fs-filename` rules require `eslint-disable` comments for legitimate array indexing and NaCl API usage
- TypeScript target does not support optional chaining (`?.`) or nullish coalescing (`??`) — use ternary operators instead
- Passphrase generation uses a large embedded word list (`src/util/passPhrase.ts`). Share view supports auto-generated (4-word) or custom manual passphrase (min 8 chars) via checkbox toggle.
- Share view quorum (`requiredShards`) is user-editable (range 2 to totalShards), defaults to majority via watcher on `totalShards`. Stored as data property, not computed. In Vue 2, converting computed to data+watcher is the standard pattern for reactive defaults the user can override.

---

## Flutter App (`banana_split_flutter/`)

Flutter port of Banana Split targeting Android and desktop (Windows/macOS/Linux). Same crypto pipeline as the web app, implemented in pure Dart.

### Commands

- **Run app:** `cd banana_split_flutter && flutter run`
- **Run all tests:** `cd banana_split_flutter && sh tests/run_all.sh` (JSON reporter with summary)
- **Run all tests (verbose):** `cd banana_split_flutter && sh tests/run_all.sh --verbose`
- **Run single test file:** `cd banana_split_flutter && flutter test test/<file>_test.dart`
- **Analyze:** `cd banana_split_flutter && flutter analyze`
- **Get deps:** `cd banana_split_flutter && flutter pub get`

### Architecture

**Crypto layer** (`lib/crypto/`):
- `shamir.dart` — Pure Dart port of `secrets.js-grempe` Shamir's Secret Sharing over GF(256). Log/exp tables, Horner's method, Lagrange interpolation.
- `crypto.dart` — Encrypt/decrypt pipeline: SHA-512 salt from title, scrypt key derivation (N=32768, r=8, p=1, dkLen=32), NaCl secretbox (XSalsa20-Poly1305). Uses `Isolate.run()` for heavy crypto to keep UI responsive.
- `passphrase.dart` — 4-word passphrase generator from 7776-word list (indexes via `randomUint16 % 2048`).

**Models** (`lib/models/`):
- `shard.dart` — Shard data class with `parse()` supporting v0/v1/v2 formats, `toJson()` with unicode escaping, `validateCompatibility()` for cross-shard consistency checks.

**State** (`lib/state/`): `ChangeNotifier` + `Provider`.
- `create_notifier.dart` — Title, secret, shard count, passphrase, generated shards.
- `restore_notifier.dart` — Scanned shards with validation, passphrase normalization, reconstruction. Error handling uses `ShardError` sealed class hierarchy (not strings) — UI localizes errors via exhaustive `switch`.
- `locale_notifier.dart` — Persists selected locale via `SharedPreferences`. Loaded at startup before `runApp()`.

**UI** (`lib/screens/`, `lib/widgets/`): Bottom nav with 4 tabs — Create (two-step wizard), Restore (scanner → passphrase → result), Files (browse/share/delete saved PDFs and PNGs), About (with version, privacy policy, licenses). Widgets: `QrGrid` (responsive QR display — 1-4 columns via `LayoutBuilder`, adapts to window width), `ShardScanner` (platform-conditional: `mobile_scanner` on Android/iOS, `camera` package + periodic `takePicture()` + `zxing2` decode on Windows), `PassphraseField` (auto/manual toggle), `LanguageSelectorButton` (flag-based locale picker in AppBar).

**Localization** (`lib/l10n/`): Flutter's official `flutter_localizations` with ARB files and code generation. 6 locales: EN, RU, TR, BE, KA, UK. All UI strings use `AppLocalizations.of(context)!`. Config in `l10n.yaml`, template is `app_en.arb`. Navigation labels are built inside `build()` (not `static const`) because they need `BuildContext`.

**Services** (`lib/services/`):
- `export_service.dart` — Save QR shards as PNGs or PDF to `getApplicationDocumentsDirectory()/banana_split/<title>/`, share via OS share sheet. QR PNGs rendered at 800px with 8% quiet zone on white background for reliable scanning. Title sanitization strips only filesystem-unsafe characters (`/\:*?"<>|`), preserving Unicode. PDF export uses bundled Roboto (Latin/Cyrillic/Turkish) and Noto Sans Georgian fonts for Unicode support — font selected by `languageCode` parameter.

**Files tab** (`lib/screens/files_screen.dart`): Scans `banana_split/` directory recursively for `.png` and `.pdf` files. Supports share (via `Share.shareXFiles`), delete with confirmation dialog, pull-to-refresh, and empty state. Parent directory name shown as subtitle for files in subdirectories.

### Key Conventions

- Crypto operations run in `Isolate.run()` — sync cores (`_shareSync`, `_reconstructSync`) are separated from async wrappers. Shard objects are serialized to `Map<String, dynamic>` for cross-isolate transfer.
- Uses `pinenacl`'s `TweetNaCl` low-level API directly (not the high-level `SecretBox` class) for byte-level compatibility with the web app's tweetnacl.
- Shard format: reads v0/v1/v2, writes v2 only. v2 uses same encoding as v1 (base64). Both web and Flutter apps can read all formats — full cross-app interoperability.
- QR codes use error correction level M (15% recovery).
- Test wrapper (`tests/run_all.sh`) uses `flutter test --reporter json` piped through a Python3 parser for clean CLI output.
- All new UI strings must be added to `lib/l10n/app_en.arb` (template) and all 5 translation files. Run `flutter gen-l10n` after editing ARB files. Use `AppLocalizations.of(context)!.keyName` in widgets.
- Camera scanner is platform-conditional: `mobile_scanner` on Android/iOS/macOS (ML Kit/Vision), `camera` package on Windows (periodic `takePicture()` every 800ms + `zxing2` decode). Uses `WidgetsBindingObserver` for lifecycle handling — disposes camera on background, re-inits on resume. `_disposed` flag prevents use-after-dispose in async callbacks. `_isPickingFile` guard prevents camera disposal during file picker dialogs (Windows file dialogs trigger `paused`/`inactive` lifecycle states). `_cameraInitialized` flag tracks first successful init for smart auto-recovery. Manual retry button shown when camera is unavailable.
- Gallery QR import supports bulk multi-file selection (`FilePicker.allowMultiple` on Windows, `ImagePicker.pickMultiImage` on mobile). Two-stage decode per file: `mobile_scanner.analyzeImage()` first (native, mobile), then `zxing2` QRCodeReader fallback (pure Dart, all platforms). Pixel values normalized via `rNormalized` (0.0-1.0) to handle any image bit depth.
- Windows builds include `launch.bat` — checks for VC++ Runtime and offers to download/install if missing.
- `LanguageSelectorButton` uses `PopupMenuButton<Locale>` with Dart records for locale data. Normalizes locale with `Locale(currentLocale.languageCode)` to match `initialValue` (avoids `Locale('en', 'US') != Locale('en')` gotcha).
- `FilesScreen` widget tests use `FakePathProvider` with `PathProviderPlatform.instance` mocking and `tester.runAsync()` for real I/O in `initState()`.
- App icon: `assets/app_icon.png` (1536x1536, padded from 1024x1536 source). Android adaptive icon with `#FFFFFF` background. Android app label is "Banana Split" (set in `AndroidManifest.xml`). Windows icon: multi-size ICO (16-256px) at `windows/runner/resources/app_icon.ico`. Windows window title, exe name (`banana_split.exe`), and version info set in `main.cpp`, `CMakeLists.txt`, and `Runner.rc`.
- PDF fonts: `assets/fonts/Roboto-Regular.ttf`, `Roboto-Bold.ttf`, `NotoSansGeorgian-Regular.ttf`. Loaded via `rootBundle.load()` in `export_service.dart`. Font chosen by locale: Georgian (`ka`) uses Noto Sans Georgian, all others use Roboto. The Dart `pdf` package defaults to Helvetica which only supports Latin-1 — any non-Latin text (Cyrillic, Georgian, etc.) requires explicitly loading a TTF via `pw.Font.ttf(ByteData)` and passing it to every `pw.TextStyle`. Remove `const` from TextStyle constructors when adding font parameters since `pw.Font` instances aren't compile-time constants.

### CI/CD

- **Flutter CI** (`.github/workflows/flutter-ci.yml`): Analyze + test on push/PR (scoped to `banana_split_flutter/`). On-demand debug APK and release Windows builds via `workflow_dispatch`.
- **Release** (`.github/workflows/release.yml`): Triggered by tag push (`v*.*.*`) or manual dispatch. Builds Android (APK + AAB), Windows (zip), and Web (single HTML file) in parallel. Creates GitHub Release with all artifacts and checksums.
- **Web App CI** (`.github/workflows/web-ci.yml`): Lint, unit tests, E2E tests, CodeQL, Trivy scan. Skips Flutter-only changes via `paths-ignore`.

### Deployment

**Web app to S3:** Download `banana-split-web-X.Y.Z.html` from GitHub Release, upload as `index.html` to an S3 bucket with static website hosting enabled. The HTML file is fully self-contained (all JS/CSS inlined) — no other assets needed.
