# Banana Split Flutter

> **Fork Notice:** This is the Flutter port from a fork of [banana_split](https://github.com/paritytech/banana_split) originally developed by [Parity Technologies](https://www.parity.io/). Original work © 2019–2020 Parity Technologies. This fork © 2026 Evgeny Mezin. Licensed under [GPLv3](../LICENSE).

Splits secrets into QR code shards using Shamir's Secret Sharing, and reconstructs them by scanning QR codes.

Platforms: Android, Windows, macOS, Linux (no iOS).

Languages: English, Russian, Turkish, Belarusian, Georgian, Ukrainian, Polish.

## How It Works

1. **Create**: Enter a title, secret text, and number of shards. The app encrypts the secret with a passphrase-derived key (scrypt + NaCl secretbox), splits the ciphertext via Shamir's Secret Sharing, and renders each shard as a QR code.

2. **Restore**: Scan the required number of QR code shards (camera or gallery import), enter the passphrase, and reconstruct the original secret.

The crypto pipeline is identical to the web app:
- SHA-512 hash of title as salt
- scrypt key derivation (N=32768, r=8, p=1, dkLen=32)
- NaCl secretbox (XSalsa20-Poly1305) encryption
- Shamir's Secret Sharing over GF(256)

## Getting Started

Prerequisites:
- Flutter SDK (>= 3.5.4)
- Android SDK (for Android builds)
- Python 3 (for test runner script)

```bash
cd banana_split_flutter
flutter pub get
flutter run
```

Run tests:
```bash
sh tests/run_all.sh              # summary only
sh tests/run_all.sh --verbose    # list each test name
```

Analyze code:
```bash
flutter analyze
```

## Shard Compatibility

| Format | Encoding | Written by | Read by |
|--------|----------|------------|---------|
| v0 | hex nonce, hex data | legacy web app | both |
| v1 | base64 nonce, base64 data | current web app | both |
| v2 | base64 nonce, base64 data | Flutter app | both |

v1 and v2 use identical encoding — the version field is only a provenance marker indicating which app created the shard. All formats are fully interoperable: shards created in either app can be reconstructed in either app.

## Windows

The Windows build includes a `launch.bat` launcher script. If the Visual C++ Runtime is not installed, the launcher offers to download and install it automatically.

Saved QR shards go to: `C:\Users\<username>\Documents\banana_split\<title>\`

## CI/CD

CI workflows are in `.github/workflows/`:
- **flutter-ci.yml** — Analyze + test on push/PR. On-demand debug APK and release Windows builds.
- **release.yml** — Tag push (`v*.*.*`) or manual dispatch. Builds Android APK/AAB, Windows zip, and Web HTML. Creates GitHub Release with SHA-256 checksums.

## Project Structure

```
lib/
  crypto/
    shamir.dart             Shamir's Secret Sharing (GF(256) arithmetic)
    crypto.dart             Encrypt/decrypt/share/reconstruct pipeline
    passphrase.dart         Word list + passphrase generation
  models/
    shard.dart              Shard data class (v0/v1/v2 parsing)
  state/
    create_notifier.dart    State for the Create flow
    restore_notifier.dart   State for the Restore flow
  screens/
    create_screen.dart      Two-step create wizard
    restore_screen.dart     Scanner + passphrase + result
    about_screen.dart       Version, privacy policy, licenses
    privacy_policy_screen.dart  Inline privacy policy + online link
  l10n/
    app_en.arb              English (template)
    app_ru.arb              Russian
    app_tr.arb              Turkish
    app_be.arb              Belarusian
    app_ka.arb              Georgian
    app_uk.arb              Ukrainian
    app_pl.arb              Polish
  widgets/
    qr_grid.dart            QR code display grid
    shard_scanner.dart      Camera + gallery scanner
    passphrase_field.dart   Auto-generate / manual toggle
  services/
    export_service.dart     Save to PNG/PDF, share via OS
  main.dart                 App entry point

assets/
  wordlist.txt              7776-word passphrase list

windows/
  launcher/
    launch.bat              VCRedist check + app launcher

tests/
  run_all.sh                Test runner wrapper
```

## License

[GNU General Public License v3.0](../LICENSE)
