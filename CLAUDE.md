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

**ShardInput** (`src/components/ShardInput.vue`): Shared input component used by Combine and Print views. Provides three shard entry modes: camera (default, uses `qrcode-stream`), upload image (multi-file, decodes via `jsqr` through `src/util/qrDecode.ts`), and paste text (multi-line JSON). Emits `decode(string)` for each successfully read shard, matching the `qrcode-stream` event interface. Includes inline feedback (success/error/partial) with auto-clear timer. Camera CSS (rounded corners) is scoped within this component.

**Build** (`vue.config.js`): Uses `html-webpack-inline-source-plugin` to inline all assets into a single HTML file. Injects git revision via `DefinePlugin`.

**Localization** (`src/i18n.ts`, `src/locales/`): vue-i18n v8 with 7 locales (EN, RU, TR, BE, KA, UK, PL) in JSON files. Browser language auto-detected on each visit (no persistence). Slavic languages (RU, UK, BE, PL) use custom `pluralizationRules` for 3-form plurals (one|few|many). Print language is independently selectable via `printLocale` on Share.vue, passed through ShardInfo → ShardQrCode using `$t(key, locale)` 3-arg form. ShardInfo's detached Vue instance for print rendering requires explicit `i18n` injection (`new Vue({ el, i18n, render })`). All new UI strings must be added to `src/locales/en.json` (template) and all 6 translation files.

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

**UI** (`lib/screens/`, `lib/widgets/`): Bottom nav with 4 tabs — Create (two-step wizard with save format picker: PDF or PNGs), Restore (scanner with bulk multi-file import → passphrase → result), Files (browse/share/delete saved PDFs and PNGs), About (with version, privacy policy, licenses). Widgets: `QrGrid` (responsive QR display — 1-4 columns via `LayoutBuilder`, adapts to window width), `ShardScanner` (platform-conditional camera: `mobile_scanner` on Android/iOS, `camera` package + periodic `takePicture()` + `zxing2` decode on Windows; also supports multi-file gallery import and paste text mode for manual JSON shard entry), `PassphraseField` (auto/manual toggle), `LanguageSelectorButton` (flag-based locale picker in AppBar).

**Localization** (`lib/l10n/`): Flutter's official `flutter_localizations` with ARB files and code generation. 7 locales: EN, RU, TR, BE, KA, UK, PL. All UI strings use `AppLocalizations.of(context)!`. Config in `l10n.yaml`, template is `app_en.arb`. Navigation labels are built inside `build()` (not `static const`) because they need `BuildContext`.

**Services** (`lib/services/`):
- `export_service.dart` — Save QR shards as PNGs or PDF to `getApplicationDocumentsDirectory()/banana_split/<title>/`, share via OS share sheet. QR PNGs rendered at 800px with 8% quiet zone on white background for reliable scanning. Title sanitization strips only filesystem-unsafe characters (`/\:*?"<>|`), preserving Unicode. PDF export uses bundled Roboto (Latin/Cyrillic/Turkish) and Noto Sans Georgian fonts for Unicode support — font selected by `languageCode` parameter.

**Files tab** (`lib/screens/files_screen.dart`): Scans `banana_split/` directory recursively for `.png` and `.pdf` files. Supports share (via `Share.shareXFiles`), delete with confirmation dialog, pull-to-refresh, and empty state. Parent directory name shown as subtitle for files in subdirectories.

### Key Conventions

- Crypto operations run in `Isolate.run()` — sync cores (`_shareSync`, `_reconstructSync`) are separated from async wrappers. Shard objects are serialized to `Map<String, dynamic>` for cross-isolate transfer.
- Uses `pinenacl`'s `TweetNaCl` low-level API directly (not the high-level `SecretBox` class) for byte-level compatibility with the web app's tweetnacl.
- Shard format: reads v0/v1/v2, writes v2 only. v2 uses same encoding as v1 (base64). Both web and Flutter apps can read all formats — full cross-app interoperability.
- QR codes use error correction level M (15% recovery).
- Test wrapper (`tests/run_all.sh`) uses `flutter test --reporter json` piped through a Python3 parser for clean CLI output.
- All new UI strings must be added to `lib/l10n/app_en.arb` (template) and all 6 translation files. Run `flutter gen-l10n` after editing ARB files. Use `AppLocalizations.of(context)!.keyName` in widgets.
- Camera scanner is platform-conditional: `mobile_scanner` on Android/iOS/macOS (ML Kit/Vision), `camera` package on Windows (periodic `takePicture()` every 800ms + `zxing2` decode). Uses `WidgetsBindingObserver` for lifecycle handling — disposes camera on background, re-inits on resume. `_disposed` flag prevents use-after-dispose in async callbacks. `_isPickingFile` guard prevents camera disposal during file picker dialogs (Windows file dialogs trigger `paused`/`inactive` lifecycle states). `_cameraInitialized` flag tracks first successful init for smart auto-recovery. Manual retry button shown when camera is unavailable.
- **F-Droid scanner variant** (`lib/widgets/shard_scanner.dart.fdroid`): FOSS-only version of `ShardScanner` that uses `camera` + `zxing2` on all platforms (no `mobile_scanner` / Google ML Kit). F-Droid's build swaps this in via prebuild (`mv shard_scanner.dart.fdroid shard_scanner.dart`) and strips `mobile_scanner` from `pubspec.yaml`. **When modifying `shard_scanner.dart`, always check if the same change needs to be applied to `shard_scanner.dart.fdroid`** — the two files must stay in sync.
- **F-Droid lockfile variant** (`banana_split_flutter/pubspec.lock.fdroid`): because the F-Droid prebuild deletes `mobile_scanner` from `pubspec.yaml`, the committed `pubspec.lock` — which still pins it — cannot be honoured. F-Droid's Flutter template runs `flutter pub get --enforce-lockfile`, which refuses to drop a dependency, so the FOSS build needs its own lock. One lockfile cannot describe two different pubspecs. **Any change to `pubspec.yaml` dependencies must regenerate both locks**, `pubspec.lock` normally and `pubspec.lock.fdroid` with `mobile_scanner` stripped first. The `F-Droid FOSS Lockfile` CI job replicates the prebuild and enforces this; it fails if either lock drifts.
- Gallery QR import supports bulk multi-file selection (`FilePicker.allowMultiple` on Windows, `ImagePicker.pickMultiImage` on mobile). Two-stage decode per file: `mobile_scanner.analyzeImage()` first (native, mobile), then `zxing2` QRCodeReader fallback (pure Dart, all platforms). Pixel values normalized via `rNormalized` (0.0-1.0) to handle any image bit depth.
- Windows builds include `launch.bat` — checks for VC++ Runtime and offers to download/install if missing.
- `LanguageSelectorButton` uses `PopupMenuButton<Locale>` with Dart records for locale data. Normalizes locale with `Locale(currentLocale.languageCode)` to match `initialValue` (avoids `Locale('en', 'US') != Locale('en')` gotcha).
- `FilesScreen` widget tests use `FakePathProvider` with `PathProviderPlatform.instance` mocking and `tester.runAsync()` for real I/O in `initState()`.
- App icon: `assets/app_icon.png` (1536x1536, padded from 1024x1536 source). Android adaptive icon with `#FFFFFF` background. Android app label is "Banana Split" (set in `AndroidManifest.xml`). Windows icon: multi-size ICO (16-256px) at `windows/runner/resources/app_icon.ico`. Windows window title, exe name (`banana_split.exe`), and version info set in `main.cpp`, `CMakeLists.txt`, and `Runner.rc`.
- PDF fonts: `assets/fonts/Roboto-Regular.ttf`, `Roboto-Bold.ttf`, `NotoSansGeorgian-Regular.ttf`. Loaded via `rootBundle.load()` in `export_service.dart`. Font chosen by locale: Georgian (`ka`) uses Noto Sans Georgian, all others use Roboto. The Dart `pdf` package defaults to Helvetica which only supports Latin-1 — any non-Latin text (Cyrillic, Georgian, etc.) requires explicitly loading a TTF via `pw.Font.ttf(ByteData)` and passing it to every `pw.TextStyle`. Remove `const` from TextStyle constructors when adding font parameters since `pw.Font` instances aren't compile-time constants.

### CI/CD

- **Flutter CI** (`.github/workflows/flutter-ci.yml`): Analyze + test, plus store-metadata validation. On-demand debug APK and release Windows builds via `workflow_dispatch`.
- **Release** (`.github/workflows/release.yml`): Triggered by tag push (`v*.*.*`) or manual dispatch. Builds Android (APK + AAB), Windows (zip), and Web (single HTML file) in parallel. Creates GitHub Release with all artifacts and checksums.
- **Web App CI** (`.github/workflows/web-ci.yml`): Lint, unit tests, E2E tests, CodeQL, Trivy scan.

**Path scoping.** Both CI workflows run on every push/PR and scope themselves
per job with `if: needs.changes.outputs.<area> == 'true'`, never with a
workflow-level `paths:` / `paths-ignore:` filter. This is deliberate: a workflow
excluded by `paths:` never reports its checks at all, so any job that is a
required status check would leave unrelated PRs stuck on "Expected — waiting for
status" forever. A job skipped by `if:` still posts a check run with conclusion
`skipped`, which rulesets accept. The `changes` job diffs three-dot against the
merge base and **fails open** — an unavailable base commit (branch creation,
force-push, scheduled run, manual dispatch) runs everything. Changing a
classifier regex is a correctness change: it can silently stop testing an area.

The Windows build runners are pinned to `windows-2022`. Flutter 3.24.5 cannot
detect Visual Studio on the image `windows-latest` now resolves to and falls
back to the VS 2019 CMake generator. Unpin only alongside a `FLUTTER_VERSION`
bump — and note F-Droid greps `FLUTTER_VERSION` out of `release.yml`, so that
bump reaches the F-Droid build too.

`release.yml` refuses to release a version the committed `pubspec.yaml`
disagrees with. The build jobs rewrite pubspec from the tag, so artifacts are
always correctly versioned — which is exactly what hid the v0.8.4 failure, where
the release shipped as `0.8.4+364` while the committed pubspec still read
`0.8.3+3` and F-Droid, which parses the committed file, never saw the update.

**Store metadata** (`tools/validate_store_metadata.py`, run by Flutter CI on
`fastlane/`, `fdroid/`, `tools/`, `pubspec.yaml`, and `lib/l10n/` changes):
checks the F-Droid recipe parses and pins full 40-char commits, that every
fastlane locale has title/short/full description, that a changelog exists for
the current `versionCode` in every locale and fits F-Droid's 500-char limit, and
that **every `app_<locale>.arb` has a matching store listing** — the check that
catches shipping a language with no store page. Run it locally the same way.

### F-Droid

- **Metadata** (`fdroid/com.nfcarchiver.banana_split.yml`): Local copy of the fdroiddata metadata YAML. The canonical version lives in the `fdroiddata` repo at `metadata/com.nfcarchiver.banana_split.yml` (fork: `gitlab.com/mezinster/fdroiddata`).
- **FOSS build**: F-Droid prebuild strips `mobile_scanner` (proprietary Google ML Kit) and swaps in `shard_scanner.dart.fdroid` which uses only `camera` + `zxing2` (pure Dart, FOSS). QR scanning works via periodic `takePicture()` every 800ms — same approach as the Windows build. It must also `cp pubspec.lock.fdroid pubspec.lock` before `pub get`, see the lockfile variant note above.
- **The local `fdroid/*.yml` is a stale copy, not a mirror.** As of 2026-08-02 it disagreed with canonical fdroiddata on the 0.8.3 commit hash (`4af44ef4…` locally vs `6b3bf07c…` canonical), on whether the 0.8.2 entry performs the FOSS swap, on `cp` vs `mv` for the scanner, and on a `JAVA_HOME` export. Read the canonical file before reasoning about the real recipe: `curl -sL https://gitlab.com/fdroid/fdroiddata/-/raw/master/metadata/com.nfcarchiver.banana_split.yml`. The effective recipe can also differ from anything committed, so for a failing build always read the job log: `curl -sL https://gitlab.com/fdroid/fdroiddata/-/jobs/<JOB_ID>/raw` (strip ANSI with `sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'` first, or greps miss). GitLab's search API needs auth, but `gh search code '<term> repo:f-droid/fdroiddata'` works against the GitHub mirror for surveying what other published apps do.
- **A failed F-Droid build is pinned to its tag commit** — fixing master does nothing for it. Recovery requires a new tag, so plan on a patch release.
- **Two binaries per release**: GitHub Release builds include `mobile_scanner` (ML Kit, fast native scanning). F-Droid builds use the FOSS variant (slightly slower but fully open-source). Both are functionally identical.
- **Version workflow**: Bump `pubspec.yaml` version+code → commit → tag → push. GitHub Actions builds the ML Kit version. F-Droid's `AutoUpdateMode: Version` auto-detects new tags, but a maintainer or update MR still sets the commit hash in `fdroiddata`.
- **Fastlane changelogs** (`fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt`): Named by `versionCode` (the `+N` in pubspec), not version name. Must be created for all 7 locales on each release.

### Deployment

**Web app to S3:** deployed by the manual **Deploy web app** workflow
(`.github/workflows/deploy-webapp.yml`) to `s3://nfcarchiver.com/banana/`,
served at `https://nfcarchiver.com/banana/`. Two jobs: an uncredentialed build
(lint, test, build, bundle sanity checks) and a credentialed deploy that assumes
an AWS role via GitHub OIDC, uploads, invalidates CloudFront, verifies the live
page carries the build's `git describe` revision, and restores the previous
version if it does not. The deploy job refuses to run unless the `S3_PREFIX`
variable is exactly `banana/` — the same deploy role can also write to the
sibling app's `app/` prefix in this bucket, so changing the deploy target
requires editing the workflow, not just the variable. Design and AWS setup:
`docs/superpowers/specs/2026-08-01-webapp-s3-deploy-design.md`.

Only `dist/index.html` is deployed. `yarn build` also emits `dist/js/*.js`,
which `html-webpack-inline-source-plugin` has already inlined into the HTML —
those files are dead output and must never be uploaded.

The build requires `fetch-depth: 0`: `vue.config.js` stamps the bundle with
`git describe --long --tags` and silently falls back to a short SHA without
tags, which would break the deploy's revision check. The workflow's own revision
step deliberately does **not** mirror that fallback — it fails the run instead.
`vue.config.js` keeps its fallback so a local `yarn build` works in a clone with
no tags, but the workflow must refuse what local development tolerates: a bare
7-hex SHA is a needle that can collide with unrelated hex constants in the 1.2 MB
bundle, letting the healthcheck wave a stale deploy through.

The rollback path is exercised with the `force_fail_verify` dispatch input, which
deploys for real and then forces verification to fail. Never exercise it by
repointing `SITE_BASE_URL` at another application — the deploy job now asserts
that `SITE_BASE_URL` is an https URL ending in `/${S3_PREFIX}` and refuses
otherwise.

`scripts/healthcheck.ts` (logic, unit-tested in `tests/unit/healthcheck.spec.ts`)
and `scripts/healthcheck-cli.ts` (entry point) are compiled standalone by the
workflow with explicit `tsc` flags — not under the project `tsconfig.json`,
whose `"module": "esnext"` is wrong for a Node CLI.
