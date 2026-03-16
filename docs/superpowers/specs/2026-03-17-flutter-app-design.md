# Banana Split Flutter App — Design Spec

## Overview

Port the Banana Split web app (Shamir's Secret Sharing for paper backups) to a Flutter application targeting Android and desktop (Windows/macOS/Linux). The Flutter app retains all core functionality — secret splitting, QR code generation, QR scanning for reconstruction — while dropping the offline-enforcement requirement.

## Target Platforms

- Android (primary mobile)
- Windows, macOS, Linux (via Flutter desktop)
- No iOS

## Architecture: Pure Dart + JS-Compatible Shamir Port

All crypto logic implemented in pure Dart. No FFI, no native dependencies.

- **NaCl secretbox** (XSalsa20-Poly1305): `pinenacl` package
- **scrypt** key derivation (N=32768, r=8, p=1, keyLen=32): `pointycastle` or `dart_scrypt`
- **Shamir's Secret Sharing**: custom `shamir.dart` ported from `secrets.js-grempe` (~400 lines GF(256) arithmetic)
- **QR generation**: `qr_flutter`
- **QR scanning**: `mobile_scanner`

## Navigation

Bottom tab bar with three tabs:

1. **Create** — split a secret into QR code shards
2. **Restore** — scan shards and reconstruct the secret
3. **About** — explanation of how Banana Split works

## Create Flow

Two-step wizard within the Create tab:

### Step 1: Input Form
- **Title** — text field, required (e.g., "My Bitcoin seed phrase")
- **Secret** — multiline text field, required, max 1024 characters. Exceeding limit disables the generate button and shows inline warning.
- **Total shards** — number input, range 3–255. Required shards computed as `floor(totalShards / 2) + 1`.

### Step 2: Results
- **Passphrase display** — auto-generated 4-word passphrase (hyphen-separated) shown prominently. Regenerate button available. User can toggle to manual entry (minimum 8 characters).
- **QR code grid** — scrollable 2-column grid, each shard rendered as a QR code with index label.
- **Save button** — exports shards as individual PNGs or a single PDF (one shard per page).
- **Share button** — invokes OS share sheet with generated files.
- Options to save/share individual shards or all at once.
- **Back button** — return to Step 1 to edit inputs.

## Restore Flow

Three steps within the Restore tab:

### Step 1: Scanner
- Camera preview with continuous batch scanning. Each successful decode shows a confirmation toast and updates progress indicator (e.g., "3 of 5 scanned").
- Gallery import button below camera preview — opens image picker for QR code images.
- Validation on each scan:
  - Duplicate shard: warning "Shard already scanned", ignored
  - Title mismatch: error "This shard belongs to a different split"
  - Nonce mismatch: error "Shard data inconsistency"
  - Version mismatch: error "Shards from different versions cannot be combined"
  - Invalid QR content: error snackbar, continue scanning
- Auto-advances to Step 2 when enough shards are collected.

### Step 2: Passphrase Input
- Text field for passphrase entry.
- Passphrase normalization: split by spaces, filter empty, rejoin with hyphens (matches web app behavior).
- "Reconstruct Secret" button.

### Step 3: Recovered Secret
- Read-only text area displaying the recovered secret.
- Wrong passphrase / corrupted data: error message "Wrong passphrase or corrupted data".

## About Screen

Brief explanation of Shamir's Secret Sharing and how Banana Split works. Derived from the web app's GeneralInfo component.

## Crypto Pipeline

Identical to the web app:

1. Salt = SHA-512 hash of the title (NaCl `crypto_hash`)
2. Derive 32-byte key from passphrase + salt using scrypt (N=32768, r=8, p=1)
3. Generate random 24-byte nonce
4. Encrypt secret with NaCl secretbox using derived key + nonce
5. Split ciphertext hex using Shamir's Secret Sharing over GF(256)
6. Encode each shard as JSON

## Shard Format

### Reading (all three versions supported):

| Version | Nonce encoding | Shard data encoding | Source |
|---------|---------------|---------------------|--------|
| v0 | hex | raw hex | legacy web app |
| v1 | base64 | bitfield char + base64 | current web app |
| v2 | base64 | bitfield char + base64 | Flutter app |

### Writing (v2 only):

```json
{
  "v": 2,
  "t": "My Bitcoin seed phrase",
  "r": 3,
  "d": "7base64encodedsharddata...",
  "n": "base64encodednonce..."
}
```

v2 is encoding-identical to v1 but carries version 2 for future extensibility.

## Passphrase Generation

- Word list ported from `passPhrase.ts` into a text asset file
- Default: 4 random words joined by hyphens
- User can toggle to manual passphrase entry (minimum 8 characters)

## State Management

`ChangeNotifier` + `Provider`. No persistent storage. Two independent notifiers:

- **CreateNotifier** — title, secret, shard count, passphrase, generated shards
- **RestoreNotifier** — scanned shards, passphrase, recovered secret

App is stateless between sessions. Closing the app discards all data.

## Project Structure

```
banana_split_flutter/
├── lib/
│   ├── main.dart
│   ├── crypto/
│   │   ├── crypto.dart            # encrypt/decrypt/share/reconstruct
│   │   ├── shamir.dart            # GF(256) Shamir port
│   │   └── passphrase.dart        # Word list + generation
│   ├── models/
│   │   └── shard.dart             # Shard data class (v0/v1/v2 parsing)
│   ├── screens/
│   │   ├── create_screen.dart     # Two-step create wizard
│   │   ├── restore_screen.dart    # Scanner + passphrase + result
│   │   └── about_screen.dart      # Info/explanation
│   ├── widgets/
│   │   ├── qr_grid.dart           # QR code display grid
│   │   ├── shard_scanner.dart     # Camera + gallery scanner widget
│   │   └── passphrase_field.dart  # Auto-gen / manual toggle input
│   └── services/
│       └── export_service.dart    # Save to PNG/PDF, share via OS
├── assets/
│   └── wordlist.txt               # Passphrase word list
└── test/
    ├── crypto_test.dart           # Core crypto round-trip tests
    ├── shamir_test.dart           # Shamir split/combine tests
    ├── shard_test.dart            # v0/v1/v2 parsing tests
    └── passphrase_test.dart       # Word list + generation tests
```

## Key Packages

| Package | Purpose |
|---------|---------|
| `pinenacl` | NaCl secretbox + hashing |
| `pointycastle` | scrypt key derivation |
| `qr_flutter` | QR code rendering |
| `mobile_scanner` | Camera QR scanning (Android + desktop) |
| `image_picker` | Gallery import for QR images |
| `share_plus` | OS share sheet |
| `pdf` | PDF generation for shard export |
| `provider` | State management |

## Platform Edge Cases

- **No camera permission:** Show explanation + settings button, fall back to gallery-only import
- **No camera hardware (desktops):** Skip camera UI, show gallery import prominently
- **Share sheet unavailable:** Fall back to save-only

## Testing Strategy

Unit tests on the crypto layer:

- Round-trip tests: share then reconstruct with correct passphrase
- Cross-version compatibility: generate v0/v1 test vectors from the web app, verify Flutter app reconstructs them
- Wrong passphrase returns null
- Edge cases: max secret length (1024), minimum shard count (3), maximum shard count (255)
- Passphrase generation: correct word count, hyphen-separated format

## Out of Scope

- iOS support
- Offline enforcement (web app's online/offline detection)
- IPFS CID integrity verification (web app's `ipfs.ts` plugin)
- Persistent storage / history of past splits
- Network communication of any kind
