# Banana Split 🍌

[![Web App CI](https://github.com/mezinster/banana_split/actions/workflows/web-ci.yml/badge.svg)](https://github.com/mezinster/banana_split/actions/workflows/web-ci.yml)
[![Flutter CI](https://github.com/mezinster/banana_split/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/mezinster/banana_split/actions/workflows/flutter-ci.yml)
[![Release](https://github.com/mezinster/banana_split/actions/workflows/release.yml/badge.svg)](https://github.com/mezinster/banana_split/actions/workflows/release.yml)

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
2. Choose how many shards to create (default: 5).
3. Banana Split encrypts the secret with a randomly generated passphrase, then splits the ciphertext into N QR codes using Shamir's scheme — requiring N/2+1 to reconstruct.
4. Print or save the QR codes. **Write the passphrase by hand on every sheet** — this protects against printer interception.

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

**Features beyond the web app:**
- Save shards as PNGs or PDF
- Files tab for browsing, sharing, and deleting saved exports
- Language selector with 6 locales (EN, RU, TR, BE, KA, UK) persisted across sessions
- Camera and gallery QR scanning with two-stage decode
- Custom Banana Split app icon

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

| Format | Web App | Flutter App |
|--------|---------|-------------|
| v0 (hex) | Read/Write | Read only |
| v1 (base64) | Read/Write | Read only |
| v2 (base64, Dart) | Read only | Read/Write |

All shard formats are fully interoperable — shards created in either app can be reconstructed in either app.

## License

[GNU General Public License v3.0](LICENSE)
