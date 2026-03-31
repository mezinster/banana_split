# Banana Split 🍌

[![Web App CI](https://github.com/mezinster/banana_split/actions/workflows/web-ci.yml/badge.svg)](https://github.com/mezinster/banana_split/actions/workflows/web-ci.yml)
[![Flutter CI](https://github.com/mezinster/banana_split/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/mezinster/banana_split/actions/workflows/flutter-ci.yml)
[![Release](https://github.com/mezinster/banana_split/actions/workflows/release.yml/badge.svg)](https://github.com/mezinster/banana_split/actions/workflows/release.yml)

> **Fork Notice:** This project is a fork of [banana_split](https://github.com/paritytech/banana_split) originally developed by [Parity Technologies](https://www.parity.io/). Original work © 2019–2020 Parity Technologies. This fork © 2026 Evgeny Mezin. Licensed under [GPLv3](LICENSE).

Banana Split uses [Shamir's Secret Sharing](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing) to split secrets into QR-code shards. Any majority of shards can reconstruct the secret — fewer reveal nothing.

**Any 3 of 5 will know everything; any 2 of 5 will know nothing.**

## Downloads

| Platform | Format | Notes |
|----------|--------|-------|
| Android | APK / AAB | Direct install or Google Play upload |
| Windows | ZIP | Extract and run (includes VC++ Runtime check) |
| Web | Single HTML file | Deploy to S3, any web server, or open locally |

All artifacts are available on the [Releases](https://github.com/mezinster/banana_split/releases) page.

## How It Works

### Splitting a Secret

1. Enter your secret (e.g., a seed phrase, private key, password).
2. Choose how many shards to create and how many are required to reconstruct (default: majority).
3. Use the auto-generated passphrase or enter your own custom passphrase (min 8 characters).
4. Banana Split encrypts the secret with the passphrase, then splits the ciphertext into N QR codes using Shamir's scheme.
5. Print or save the QR codes. **Write the passphrase by hand on every sheet** — this protects against printer interception.

### Reconstructing a Secret

1. Scan a majority of QR code shards (e.g., 3 of 5) using camera or gallery import.
2. Enter the passphrase.
3. Your secret is restored.

## Why Banana Split?

A single paper backup is vulnerable: anyone who sees it can copy it without you knowing. Splitting it in half means losing one piece loses everything.

With Banana Split, you split into 5 pieces and distribute them. Losing 2 pieces is fine — any 3 can reconstruct. And 2 colluding holders learn nothing about your secret.

## Architecture

This repo contains two implementations sharing the same cryptographic protocol:

### Web App (root)

Vue 2 + TypeScript single-page app. Builds to a **single self-contained HTML file** with all JS/CSS inlined — no server, no dependencies at runtime.

**Crypto pipeline:** scrypt key derivation → NaCl secretbox (XSalsa20-Poly1305) encryption → Shamir split over GF(256).

### Flutter App (`banana_split_flutter/`)

Native app for Android and Windows (also builds for macOS/Linux). Pure Dart implementation of the same crypto pipeline using `pinenacl` and a custom Shamir port.

**Additional features:**
- Save shards as PNGs or PDF with full Unicode font support (Roboto + Noto Sans Georgian)
- Files tab for browsing, sharing, and deleting saved exports
- Language selector with 7 locales (EN, RU, TR, BE, KA, UK, PL) persisted across sessions
- Camera and gallery QR scanning with two-stage decode
- Custom Banana Split app icon

**Shared features (both apps):**
- Custom passphrase or auto-generated passphrase
- User-selectable quorum (how many shards required to reconstruct)
- Full shard format interoperability (v0, v1, v2)

## Development

### Web App

Requires Node.js (see `.nvmrc`) and Yarn.

```bash
yarn install          # Install dependencies
yarn serve            # Dev server with hot reload
yarn build            # Production build → dist/index.html
yarn lint             # ESLint
yarn test:unit        # Jest unit tests
yarn test:e2e         # Playwright E2E tests (auto-starts dev server)
```

### Flutter App

Requires Flutter SDK (see `FLUTTER_VERSION` in CI workflow).

```bash
cd banana_split_flutter
flutter pub get                    # Install dependencies
flutter run                        # Run on connected device
flutter test                       # Run all tests
flutter test test/<file>_test.dart # Run single test file
flutter analyze                    # Static analysis
```

## CI/CD

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| **Web App CI** | Push/PR to master | Lint, unit tests, E2E tests, CodeQL, Trivy scan |
| **Flutter CI** | Push/PR to master (Flutter paths) | Analyze, test, on-demand debug APK/Windows builds |
| **Release** | Tag `v*.*.*` or manual dispatch | Builds all platforms (Android APK+AAB, Windows ZIP, Web HTML), creates GitHub Release with checksums |

## Deploying the Web App

Download the HTML file from a GitHub Release and upload to your hosting:

```bash
# S3 example
aws s3 cp banana-split-web-X.Y.Z.html s3://YOUR-BUCKET/index.html \
  --content-type "text/html"
```

The file is fully self-contained — no additional assets, no routing configuration, no backend required.

## Shard Compatibility

| Format | Encoding | Written by | Read by |
|--------|----------|------------|---------|
| v0 | hex nonce, hex data | legacy web app | both |
| v1 | base64 nonce, base64 data | current web app | both |
| v2 | base64 nonce, base64 data | Flutter app | both |

v1 and v2 use identical encoding — the version field is only a provenance marker indicating which app created the shard. All formats are fully interoperable: shards created in either app can be reconstructed in either app.

## License

[GNU General Public License v3.0](LICENSE)
