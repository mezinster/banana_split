# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Banana Split is a Vue 2 + TypeScript web app that uses Shamir's Secret Sharing to split secrets (e.g., paper backups) into N QR-code shards, requiring N/2+1 to reconstruct. It builds to a **single self-contained HTML file** (all JS/CSS inlined) designed to run offline.

## Commands

- **Dev server:** `yarn serve`
- **Build:** `yarn build` (produces self-contained HTML in `dist/`)
- **Lint:** `yarn lint` (ESLint with vue, prettier, and security plugins)
- **Unit tests:** `yarn test:unit` (Jest, tests in `tests/unit/`)
- **Run single unit test:** `yarn test:unit --testPathPattern=<pattern>`
- **E2E tests:** `yarn test:e2e` (Playwright with Chromium, auto-starts dev server on port 8888)

## Architecture

**Crypto pipeline** (`src/util/crypto.ts`): Core logic — encrypts secret with scrypt-derived key + NaCl secretbox, then splits ciphertext via `secrets.js-grempe` (Shamir). Supports v0 (hex-encoded nonces) and v1 (base64-encoded nonces/shards) formats. Exports `share()`, `parse()`, `reconstruct()`.

**Vue plugins** (`src/plugins/`):
- `online.ts` — global `isOnline` computed property; app enforces offline-only usage
- `ipfs.ts` — computes IPFS CID of current page for integrity verification

**Views** (`src/views/`): Four routes — Info (landing), Share (split a secret), Print (QR code printout), Combine (scan QR codes to reconstruct).

**Build** (`vue.config.js`): Uses `html-webpack-inline-source-plugin` to inline all assets into a single HTML file. Injects git revision via `DefinePlugin`.

## Key Conventions

- Path alias `@/` maps to `src/` (configured in jest and webpack)
- ESLint security plugin is active — `detect-object-injection` and `detect-non-literal-fs-filename` rules require `eslint-disable` comments for legitimate array indexing and NaCl API usage
- Passphrase generation uses a large embedded word list (`src/util/passPhrase.ts`)

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

**State** (`lib/state/`): `ChangeNotifier` + `Provider`, no persistent storage.
- `create_notifier.dart` — Title, secret, shard count, passphrase, generated shards.
- `restore_notifier.dart` — Scanned shards with validation, passphrase normalization, reconstruction.

**UI** (`lib/screens/`, `lib/widgets/`): Bottom nav with Create (two-step wizard), Restore (scanner → passphrase → result), About. Widgets: `QrGrid` (2-column QR display), `ShardScanner` (camera + gallery import), `PassphraseField` (auto/manual toggle).

**Services** (`lib/services/`):
- `export_service.dart` — Save QR shards as PNGs or PDF, share via OS share sheet.

### Key Conventions

- Crypto operations run in `Isolate.run()` — sync cores (`_shareSync`, `_reconstructSync`) are separated from async wrappers. Shard objects are serialized to `Map<String, dynamic>` for cross-isolate transfer.
- Uses `pinenacl`'s `TweetNaCl` low-level API directly (not the high-level `SecretBox` class) for byte-level compatibility with the web app's tweetnacl.
- Shard format: reads v0/v1/v2, writes v2 only. v2 shards are NOT backward-compatible with the current web app.
- QR codes use error correction level M (15% recovery).
- Test wrapper (`tests/run_all.sh`) uses `flutter test --reporter json` piped through a Python3 parser for clean CLI output.
