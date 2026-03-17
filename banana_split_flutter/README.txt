Banana Split Flutter
====================

A Flutter port of the Banana Split web app. Splits secrets into QR code
shards using Shamir's Secret Sharing, and reconstructs them by scanning
QR codes.

Platforms: Android, Windows, macOS, Linux (no iOS).


How It Works
------------

1. CREATE: Enter a title, secret text, and number of shards. The app
   encrypts the secret with a passphrase-derived key (scrypt + NaCl
   secretbox), splits the ciphertext via Shamir's Secret Sharing, and
   renders each shard as a QR code.

2. RESTORE: Scan the required number of QR code shards (camera or
   gallery import), enter the passphrase, and reconstruct the original
   secret.

The crypto pipeline is identical to the web app:
  - SHA-512 hash of title as salt
  - scrypt key derivation (N=32768, r=8, p=1, dkLen=32)
  - NaCl secretbox (XSalsa20-Poly1305) encryption
  - Shamir's Secret Sharing over GF(256)


Getting Started
---------------

Prerequisites:
  - Flutter SDK (>= 3.5.4)
  - Android SDK (for Android builds)
  - Python 3 (for test runner script)

Install dependencies:
  cd banana_split_flutter
  flutter pub get

Run the app:
  flutter run

Run tests:
  sh tests/run_all.sh              # summary only
  sh tests/run_all.sh --verbose    # list each test name

Analyze code:
  flutter analyze


Shard Compatibility
-------------------

The Flutter app reads shards from all versions:
  - v0: legacy web app (hex nonces, raw hex shard data)
  - v1: current web app (base64 nonces, bitfield + base64 data)
  - v2: Flutter app (same encoding as v1, version 2)

The Flutter app writes v2 shards only. Note: the current web app does
not handle v2 shards — they are forward-incompatible.


Project Structure
-----------------

lib/
  crypto/
    shamir.dart         Shamir's Secret Sharing (GF(256) arithmetic)
    crypto.dart         Encrypt/decrypt/share/reconstruct pipeline
    passphrase.dart     Word list + passphrase generation
  models/
    shard.dart          Shard data class (v0/v1/v2 parsing)
  state/
    create_notifier.dart    State for the Create flow
    restore_notifier.dart   State for the Restore flow
  screens/
    create_screen.dart      Two-step create wizard
    restore_screen.dart     Scanner + passphrase + result
    about_screen.dart       Info/explanation
  widgets/
    qr_grid.dart            QR code display grid
    shard_scanner.dart      Camera + gallery scanner
    passphrase_field.dart   Auto-generate / manual toggle
  services/
    export_service.dart     Save to PNG/PDF, share via OS
  main.dart                 App entry point

assets/
  wordlist.txt              7776-word passphrase list

tests/
  run_all.sh                Test runner wrapper


License
-------

See the repository root for license information.
