# Changelog

All notable changes to this project will be documented in this file.

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
