# About Screen Enhancements & App Localization — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add version display, privacy policy, and licenses to the About screen, then localize the entire app into 6 languages (EN, RU, TR, BE, KA, UK).

**Architecture:** Flutter's official `flutter_localizations` with ARB files and code generation. New `PrivacyPolicyScreen` for inline policy display. `package_info_plus` for runtime version. Error messages in model/crypto layers refactored to enum-based codes, localized at the UI layer.

**Tech Stack:** Flutter, `flutter_localizations`, `intl`, `package_info_plus`, `url_launcher`

**Spec:** `docs/superpowers/specs/2026-03-17-about-and-localization-design.md`

---

## Chunk 1: Infrastructure + About Screen

### Task 1: Add dependencies and localization config

**Files:**
- Modify: `banana_split_flutter/pubspec.yaml`
- Create: `banana_split_flutter/l10n.yaml`

- [ ] **Step 1: Update pubspec.yaml**

Add dependencies and enable code generation. In `banana_split_flutter/pubspec.yaml`:

Under `dependencies:`, after `flutter:` SDK dependency, add:

```yaml
  flutter_localizations:
    sdk: flutter
  intl: any
  package_info_plus: ^8.0.0
  url_launcher: ^6.3.0
```

Under `flutter:`, add:

```yaml
  generate: true
```

- [ ] **Step 2: Create l10n.yaml**

Create `banana_split_flutter/l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

- [ ] **Step 3: Create English ARB template with initial keys**

Create `banana_split_flutter/lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "Banana Split",
  "tabCreate": "Create",
  "tabRestore": "Restore",
  "tabAbout": "About",

  "createEncrypting": "Encrypting...",
  "createTitleLabel": "Title",
  "createTitleHint": "e.g. My wallet seed phrase",
  "createSecretLabel": "Secret",
  "createSecretHint": "Enter the secret to split",
  "createSecretTooLong": "Secret exceeds 1024 characters",
  "createSecretCharCount": "{count}/1024 characters",
  "@createSecretCharCount": { "placeholders": { "count": { "type": "int" } } },
  "createTotalShardsLabel": "Total shards",
  "createTotalShardsHint": "3\u2013255",
  "createRequiredLabel": "Required to restore",
  "createRequiredHint": "2\u2013{max}",
  "@createRequiredHint": { "placeholders": { "max": { "type": "int" } } },
  "createQuorumHelper": "{required} of {total} shards needed to restore",
  "@createQuorumHelper": { "placeholders": { "required": { "type": "int" }, "total": { "type": "int" } } },
  "createGenerateButton": "Generate QR Shards",
  "createSavePassphrase": "Save your passphrase!",
  "createPassphraseNeeded": "You will need this passphrase to restore your secret.",
  "createBack": "Back",
  "createSaveAllTooltip": "Save all shards",
  "createShareAllTooltip": "Share all shards",
  "createSavedTo": "Saved to {path}",
  "@createSavedTo": { "placeholders": { "path": { "type": "String" } } },

  "restoreCombineTitle": "Combine shards for \"{title}\"",
  "@restoreCombineTitle": { "placeholders": { "title": { "type": "String" } } },
  "restoreCombineTitleDefault": "Combine shards",
  "restoreStartOver": "Start over",
  "restoreAllCollected": "All shards collected!",
  "restorePassphraseLabel": "Passphrase",
  "restorePassphraseHint": "Enter passphrase to decrypt",
  "restoreReconstructButton": "Reconstruct Secret",
  "restoreDecrypting": "Decrypting...",
  "restoreRecoveredSecret": "Recovered Secret",
  "restoreShardScanned": "Shard {count} of {total} scanned",
  "@restoreShardScanned": { "placeholders": { "count": { "type": "int" }, "total": { "type": "int" } } },

  "scannerScanFirst": "Scan first shard...",
  "scannerProgress": "{count} of {total} scanned",
  "@scannerProgress": { "placeholders": { "count": { "type": "int" }, "total": { "type": "int" } } },
  "scannerNoQrFound": "No QR code found in image",
  "scannerCameraDenied": "Camera permission denied.\nGrant camera access in Settings, or import QR images below.",
  "scannerOpenSettings": "Open Settings",
  "scannerCameraUnavailable": "Camera not available.\nUse the import button below to load QR code images.",
  "scannerImportGallery": "Import from gallery",

  "passphraseTitle": "Passphrase",
  "passphraseAutoGenerate": "Auto-generate",
  "passphraseEnterManually": "Enter manually",
  "passphraseManualHint": "Enter your passphrase (min 8 characters)",
  "passphraseRegenerateTooltip": "Generate new passphrase",

  "shardLabel": "Shard {index} of {total}",
  "@shardLabel": { "placeholders": { "index": { "type": "int" }, "total": { "type": "int" } } },
  "shardSaveTooltip": "Save this shard",
  "shardShareTooltip": "Share this shard",
  "shardSaved": "Shard saved",

  "errorSaving": "Error saving: {error}",
  "@errorSaving": { "placeholders": { "error": { "type": "String" } } },
  "errorSharing": "Error sharing: {error}",
  "@errorSharing": { "placeholders": { "error": { "type": "String" } } },

  "errorEmptyQr": "QR code is empty.",
  "errorDuplicateShard": "This shard has already been scanned.",
  "errorParseFailed": "Failed to parse shard: {detail}",
  "@errorParseFailed": { "placeholders": { "detail": { "type": "String" } } },
  "errorTitleMismatch": "Title mismatch: expected \"{expected}\", got \"{actual}\".",
  "@errorTitleMismatch": { "placeholders": { "expected": { "type": "String" }, "actual": { "type": "String" } } },
  "errorNonceMismatch": "Nonce mismatch: this shard belongs to a different secret.",
  "errorRequiredMismatch": "Required shards mismatch: this shard belongs to a different set.",
  "errorVersionMismatch": "Version mismatch: this shard belongs to a different set.",
  "errorNotEnoughShards": "Not enough shards: need {required}, got {got}.",
  "@errorNotEnoughShards": { "placeholders": { "required": { "type": "int" }, "got": { "type": "int" } } },
  "errorDecryptionFailed": "Unable to decrypt the secret. Wrong passphrase or corrupted data.",

  "pdfShardLabel": "Shard {index} of {total}",
  "@pdfShardLabel": { "placeholders": { "index": { "type": "int" }, "total": { "type": "int" } } },
  "pdfRequiresShards": "Requires {count} shards to reconstruct",
  "@pdfRequiresShards": { "placeholders": { "count": { "type": "int" } } },
  "pdfPassphrasePlaceholder": "Write your passphrase here: ___________________________",

  "aboutHeading": "About Banana Split",
  "aboutDescription": "Banana Split lets you securely split a secret \u2014 such as a password, seed phrase, or private key \u2014 into multiple shards using Shamir\u2019s Secret Sharing.",
  "aboutWhatIsSss": "What is Shamir\u2019s Secret Sharing?",
  "aboutSssExplanation": "Shamir\u2019s Secret Sharing (SSS) is a cryptographic algorithm invented by Adi Shamir in 1979. It divides a secret into N pieces (shards) such that any K of them (the threshold) are sufficient to reconstruct the original secret, but K\u20131 or fewer shards reveal nothing about the secret.",
  "aboutHowItWorks": "How Banana Split works",
  "aboutHowItWorksBody": "1. You enter a secret and a passphrase.\n2. The secret is encrypted with your passphrase using NaCl secretbox (XSalsa20-Poly1305).\n3. The encrypted data is split into N shards using Shamir\u2019s Secret Sharing over GF(256).\n4. Each shard is encoded as a QR code that you can print or distribute to trusted custodians.\n5. To recover the secret, you scan at least K shards and enter the passphrase. The shards are recombined and the data is decrypted.",
  "aboutSecurityNotes": "Security notes",
  "aboutSecurityNotesBody": "\u2022 All cryptographic operations happen on-device. No data is ever transmitted to a server.\n\u2022 The passphrase adds an additional layer of protection: even if enough shards are compromised, the attacker still needs the passphrase to decrypt the secret.\n\u2022 Store shards separately and in physically secure locations.",
  "aboutVersion": "Version {version} (Build {build})",
  "@aboutVersion": { "placeholders": { "version": { "type": "String" }, "build": { "type": "String" } } },
  "aboutPrivacyPolicy": "Privacy Policy",
  "aboutLicenses": "Open-source licenses",

  "privacyPolicyTitle": "Privacy Policy",
  "privacyPolicyViewOnline": "View online",
  "privacyPolicyBody": "Privacy Policy for Banana Split\n\nLast updated: March 2026\n\n1. Data Collection\nBanana Split does not collect, store, or transmit any personal data. All cryptographic operations are performed entirely on your device.\n\n2. Network Access\nBanana Split does not connect to any server. Your secrets, passphrases, and shards never leave your device unless you explicitly export or share them using the built-in export features.\n\n3. Camera Access\nBanana Split requests camera access solely to scan QR codes containing shards. Camera data is processed on-device and is never recorded or transmitted.\n\n4. Storage\nExported files (PNG images, PDF documents) are saved to your device\u2019s local storage. You are responsible for managing and securing these files.\n\n5. Third-Party Services\nBanana Split does not integrate with any third-party analytics, advertising, or tracking services.\n\n6. Open Source\nBanana Split is open-source software licensed under the GNU General Public License v3.0. The source code is available at https://github.com/mezinster/banana_split.\n\n7. Contact\nFor questions about this privacy policy, please open an issue on the GitHub repository."
}
```

- [ ] **Step 4: Run flutter gen-l10n to verify ARB compiles**

```bash
cd banana_split_flutter && flutter gen-l10n
```

Expected: generates `lib/flutter_gen/gen_l10n/app_localizations.dart` with no errors.

- [ ] **Step 5: Wire up localization in main.dart**

In `banana_split_flutter/lib/main.dart`:

Add imports:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

In the `MaterialApp` constructor (inside `BananaSplitApp.build()`), add:

```dart
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
```

- [ ] **Step 6: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

Expected: no errors, all tests pass.

- [ ] **Step 7: Commit**

```bash
git add banana_split_flutter/pubspec.yaml banana_split_flutter/l10n.yaml banana_split_flutter/lib/l10n/app_en.arb banana_split_flutter/lib/main.dart
git commit -m "feat: add l10n infrastructure with English ARB template"
```

---

### Task 2: Create PRIVACY_POLICY.md and PrivacyPolicyScreen

**Files:**
- Create: `PRIVACY_POLICY.md` (repo root)
- Create: `banana_split_flutter/lib/screens/privacy_policy_screen.dart`

- [ ] **Step 1: Create PRIVACY_POLICY.md**

Create `/home/mezinster/banana_split/PRIVACY_POLICY.md`:

```markdown
# Privacy Policy for Banana Split

**Last updated:** March 2026

## 1. Data Collection

Banana Split does not collect, store, or transmit any personal data. All cryptographic operations are performed entirely on your device.

## 2. Network Access

Banana Split does not connect to any server. Your secrets, passphrases, and shards never leave your device unless you explicitly export or share them using the built-in export features.

## 3. Camera Access

Banana Split requests camera access solely to scan QR codes containing shards. Camera data is processed on-device and is never recorded or transmitted.

## 4. Storage

Exported files (PNG images, PDF documents) are saved to your device's local storage. You are responsible for managing and securing these files.

## 5. Third-Party Services

Banana Split does not integrate with any third-party analytics, advertising, or tracking services.

## 6. Open Source

Banana Split is open-source software licensed under the GNU General Public License v3.0. The source code is available at [github.com/mezinster/banana_split](https://github.com/mezinster/banana_split).

## 7. Contact

For questions about this privacy policy, please open an issue on the [GitHub repository](https://github.com/mezinster/banana_split/issues).
```

- [ ] **Step 2: Create PrivacyPolicyScreen**

Create `banana_split_flutter/lib/screens/privacy_policy_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _privacyUrl =
      'https://github.com/mezinster/banana_split/blob/master/PRIVACY_POLICY.md';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacyPolicyTitle),
        actions: [
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(_privacyUrl)),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.privacyPolicyViewOnline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.privacyPolicyBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run flutter analyze**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add PRIVACY_POLICY.md banana_split_flutter/lib/screens/privacy_policy_screen.dart
git commit -m "feat: add privacy policy (repo file + in-app screen)"
```

---

### Task 3: Enhance About screen

**Files:**
- Modify: `banana_split_flutter/lib/screens/about_screen.dart`
- Modify: `banana_split_flutter/lib/main.dart`

- [ ] **Step 1: Register GPLv3 license in main.dart**

In `banana_split_flutter/lib/main.dart`, add import:

```dart
import 'package:flutter/foundation.dart';
```

In `main()`, before `runApp()`, add:

```dart
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Banana Split'],
      'GNU General Public License v3.0\n\n'
      'This program is free software: you can redistribute it and/or modify '
      'it under the terms of the GNU General Public License as published by '
      'the Free Software Foundation, either version 3 of the License, or '
      '(at your option) any later version.\n\n'
      'This program is distributed in the hope that it will be useful, '
      'but WITHOUT ANY WARRANTY; without even the implied warranty of '
      'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the '
      'GNU General Public License for more details.\n\n'
      'You should have received a copy of the GNU General Public License '
      'along with this program. If not, see https://www.gnu.org/licenses/.',
    );
  });
```

- [ ] **Step 2: Rewrite about_screen.dart with version, privacy, licenses**

Replace `banana_split_flutter/lib/screens/about_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:banana_split_flutter/screens/privacy_policy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.aboutHeading, style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(l10n.aboutDescription, style: textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text(l10n.aboutWhatIsSss, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.aboutSssExplanation, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.aboutHowItWorks, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.aboutHowItWorksBody, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Text(l10n.aboutSecurityNotes, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.aboutSecurityNotesBody, style: textTheme.bodyMedium),
          const Divider(height: 32),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final info = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.aboutVersion(info.version, info.buildNumber),
                  style: textTheme.bodySmall,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.aboutPrivacyPolicy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.aboutLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: l10n.aboutVersion(info.version, info.buildNumber),
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.security, size: 48),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

Expected: no errors, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add banana_split_flutter/lib/screens/about_screen.dart banana_split_flutter/lib/main.dart
git commit -m "feat: add version display, privacy policy, and licenses to About screen"
```

---

### Task 4: Localize main.dart navigation

**Files:**
- Modify: `banana_split_flutter/lib/main.dart`

The `_destinations` list is currently `static const` which is incompatible with localized strings that need `BuildContext`. Refactor to build destinations inside `build()`.

- [ ] **Step 1: Refactor HomeShell to use localized navigation**

In `banana_split_flutter/lib/main.dart`, add import if not already present:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

Replace the `_HomeShellState` class. Remove the `static const` lists and build them inside `build()`:

```dart
class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    CreateScreen(),
    RestoreScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.lock_outline),
            selectedIcon: const Icon(Icons.lock),
            label: l10n.tabCreate,
          ),
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: l10n.tabRestore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.info_outline),
            selectedIcon: const Icon(Icons.info),
            label: l10n.tabAbout,
          ),
        ],
      ),
    );
  }
}
```

Also update `MaterialApp.title` to use a fixed English string (title is used by OS task switcher and should stay non-localized, while the AppBar uses the localized version):

```dart
title: 'Banana Split',
```

- [ ] **Step 2: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

- [ ] **Step 3: Commit**

```bash
git add banana_split_flutter/lib/main.dart
git commit -m "feat: localize navigation labels and app bar title"
```

---

## Chunk 2: Localize All Screens and Widgets

### Task 5: Localize create_screen.dart

**Files:**
- Modify: `banana_split_flutter/lib/screens/create_screen.dart`

- [ ] **Step 1: Replace all hardcoded strings with l10n calls**

Add import at top:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

In `CreateScreen.build()`, get `final l10n = AppLocalizations.of(context)!;` and pass it to child widgets.

In `_InputForm`, the `build()` method needs `AppLocalizations.of(context)!` at the top:

Replace every hardcoded string:

| Line | Old | New |
|------|-----|-----|
| 23 | `'Encrypting...'` | `l10n.createEncrypting` |
| 82 | `'Title'` (labelText) | `l10n.createTitleLabel` |
| 84 | `'e.g. My wallet seed phrase'` | `l10n.createTitleHint` |
| 92 | `'Secret'` (labelText) | `l10n.createSecretLabel` |
| 94 | `'Enter the secret to split'` | `l10n.createSecretHint` |
| 96 | `'Secret exceeds 1024 characters'` | `l10n.createSecretTooLong` |
| 98-99 | `'${notifier.secret.length}/1024 characters'` | `l10n.createSecretCharCount(notifier.secret.length)` |
| 123 | `'Total shards'` | `l10n.createTotalShardsLabel` |
| 125 | `'3–255'` | `l10n.createTotalShardsHint` |
| 141 | `'Required to restore'` | `l10n.createRequiredLabel` |
| 143 | `'2–${notifier.totalShards}'` | `l10n.createRequiredHint(notifier.totalShards)` |
| 153 | `'${notifier.requiredShards} of ${notifier.totalShards} shards needed...'` | `l10n.createQuorumHelper(notifier.requiredShards, notifier.totalShards)` |
| 175 | `'Generate QR Shards'` | `l10n.createGenerateButton` |

In `_ResultsView.build()`, add `final l10n = AppLocalizations.of(context)!;` and replace:

| Line | Old | New |
|------|-----|-----|
| 210 | `'Save your passphrase!'` | `l10n.createSavePassphrase` |
| 232 | `'You will need this passphrase...'` | `l10n.createPassphraseNeeded` |
| 249 | `'Back'` | `l10n.createBack` |
| 254 | `'Save all shards'` tooltip | `l10n.createSaveAllTooltip` |
| 264 | `'Saved to $path'` | `l10n.createSavedTo(path)` |
| 270 | `'Error saving: $e'` | `l10n.errorSaving(e.toString())` |
| 278 | `'Share all shards'` tooltip | `l10n.createShareAllTooltip` |
| 288 | `'Error sharing: $e'` | `l10n.errorSharing(e.toString())` |

Note: `const` keywords on widgets containing localized text must be removed (e.g., `const Text('Encrypting...')` becomes `Text(l10n.createEncrypting)`). Same for `const InputDecoration` and `const SizedBox` that don't contain text — those can stay `const`.

- [ ] **Step 2: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

- [ ] **Step 3: Commit**

```bash
git add banana_split_flutter/lib/screens/create_screen.dart
git commit -m "feat: localize create screen strings"
```

---

### Task 6: Localize passphrase_field.dart

**Files:**
- Modify: `banana_split_flutter/lib/widgets/passphrase_field.dart`

- [ ] **Step 1: Replace hardcoded strings**

Add import:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

In `build()`, add `final l10n = AppLocalizations.of(context)!;` and replace:

| Line | Old | New |
|------|-----|-----|
| 26 | `'Passphrase'` | `l10n.passphraseTitle` |
| 30 | `isManual ? 'Auto-generate' : 'Enter manually'` | `isManual ? l10n.passphraseAutoGenerate : l10n.passphraseEnterManually` |
| 40 | `'Enter your passphrase (min 8 characters)'` | `l10n.passphraseManualHint` |
| 66 | `'Generate new passphrase'` tooltip | `l10n.passphraseRegenerateTooltip` |

Remove `const` from `InputDecoration` on line 38.

- [ ] **Step 2: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

- [ ] **Step 3: Commit**

```bash
git add banana_split_flutter/lib/widgets/passphrase_field.dart
git commit -m "feat: localize passphrase field strings"
```

---

### Task 7: Localize restore_screen.dart and refactor error handling

**Files:**
- Modify: `banana_split_flutter/lib/screens/restore_screen.dart`
- Modify: `banana_split_flutter/lib/state/restore_notifier.dart`

The notifier currently returns error strings from `addShard()`. We need to introduce a `ShardError` sealed class so the UI can localize error messages.

- [ ] **Step 1: Add ShardError sealed class to restore_notifier.dart**

At the top of `banana_split_flutter/lib/state/restore_notifier.dart`, before `class RestoreNotifier`, add:

```dart
sealed class ShardError {
  const ShardError();
}

class EmptyQrError extends ShardError {
  const EmptyQrError();
}

class DuplicateShardError extends ShardError {
  const DuplicateShardError();
}

class ParseError extends ShardError {
  final String detail;
  const ParseError(this.detail);
}

class TitleMismatchError extends ShardError {
  final String expected;
  final String actual;
  const TitleMismatchError(this.expected, this.actual);
}

class NonceMismatchError extends ShardError {
  const NonceMismatchError();
}

class RequiredMismatchError extends ShardError {
  const RequiredMismatchError();
}

class VersionMismatchError extends ShardError {
  const VersionMismatchError();
}

class DecryptionError extends ShardError {
  const DecryptionError();
}

class NotEnoughShardsError extends ShardError {
  final int required;
  final int got;
  const NotEnoughShardsError(this.required, this.got);
}
```

- [ ] **Step 2: Change addShard return type from String? to ShardError?**

Replace the `addShard` method body:

```dart
  ShardError? addShard(String rawQrData) {
    if (rawQrData.trim().isEmpty) {
      return const EmptyQrError();
    }

    if (_rawCodes.contains(rawQrData)) {
      return const DuplicateShardError();
    }

    Shard shard;
    try {
      shard = Shard.parse(rawQrData);
    } on FormatException catch (e) {
      return ParseError(e.message);
    } catch (e) {
      return ParseError(e.toString());
    }

    if (_shards.isNotEmpty) {
      final first = _shards.first;
      if (shard.title != first.title) {
        return TitleMismatchError(first.title, shard.title);
      }
      if (shard.nonce != first.nonce) {
        return const NonceMismatchError();
      }
      if (shard.requiredShards != first.requiredShards) {
        return const RequiredMismatchError();
      }
      if (shard.version != first.version) {
        return const VersionMismatchError();
      }
    }

    _shards.add(shard);
    _rawCodes.add(rawQrData);
    _error = null;
    notifyListeners();
    return null;
  }
```

- [ ] **Step 3: Change error field to ShardError? and update reconstruct()**

Change the `_error` field and getter:

```dart
  ShardError? _error;
```

```dart
  ShardError? get error => _error;
```

Update `reconstruct()` to set typed errors:

```dart
  Future<void> reconstruct() async {
    if (_shards.isEmpty) return;

    _isDecrypting = true;
    _error = null;
    notifyListeners();

    try {
      final normalizedPassphrase = _passphrase
          .split(' ')
          .where((part) => part.isNotEmpty)
          .join('-');

      _recoveredSecret = await BananaCrypto.reconstruct(
        List.unmodifiable(_shards),
        normalizedPassphrase,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Not enough shards')) {
        // Extract numbers if possible, otherwise use defaults
        final match = RegExp(r'need (\d+), got (\d+)').firstMatch(msg);
        if (match != null) {
          _error = NotEnoughShardsError(
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
          );
        } else {
          _error = const DecryptionError();
        }
      } else {
        _error = const DecryptionError();
      }
    } finally {
      _isDecrypting = false;
      notifyListeners();
    }
  }
```

- [ ] **Step 4: Localize restore_screen.dart**

Add import:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

Add a helper function at the top of the file (after imports) to convert `ShardError` to localized string:

```dart
String _localizeError(AppLocalizations l10n, ShardError error) {
  return switch (error) {
    EmptyQrError() => l10n.errorEmptyQr,
    DuplicateShardError() => l10n.errorDuplicateShard,
    ParseError(:final detail) => l10n.errorParseFailed(detail),
    TitleMismatchError(:final expected, :final actual) =>
      l10n.errorTitleMismatch(expected, actual),
    NonceMismatchError() => l10n.errorNonceMismatch,
    RequiredMismatchError() => l10n.errorRequiredMismatch,
    VersionMismatchError() => l10n.errorVersionMismatch,
    DecryptionError() => l10n.errorDecryptionFailed,
    NotEnoughShardsError(:final required, :final got) =>
      l10n.errorNotEnoughShards(required, got),
  };
}
```

In `RestoreScreen.build()`, add `final l10n = AppLocalizations.of(context)!;` and replace:

| Line | Old | New |
|------|-----|-----|
| 20 | `'Combine shards for "${notifier.title}"'` | `l10n.restoreCombineTitle(notifier.title)` |
| 21 | `'Combine shards'` | `l10n.restoreCombineTitleDefault` |
| 39 | `'Start over'` | `l10n.restoreStartOver` |

In `_ScannerView.build()`, add `final l10n = AppLocalizations.of(context)!;` and update `onScanned`:

```dart
        final error = notifier.addShard(rawData);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_localizeError(l10n, error))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.restoreShardScanned(
                  notifier.scannedCount,
                  notifier.requiredCount,
                ),
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
```

In `_PassphraseViewState.build()`, add `final l10n = AppLocalizations.of(context)!;` and replace:

| Line | Old | New |
|------|-----|-----|
| 112 | `'All shards collected!'` | `l10n.restoreAllCollected` |
| 120 | `'Passphrase'` | `l10n.restorePassphraseLabel` |
| 122 | `'Enter passphrase to decrypt'` | `l10n.restorePassphraseHint` |
| 132 | `notifier.error!` | `_localizeError(l10n, notifier.error!)` |
| 142 | `'Reconstruct Secret'` | `l10n.restoreReconstructButton` |
| 146 | `'Decrypting...'` | `l10n.restoreDecrypting` |

In `_RecoveredView.build()`, add `final l10n = AppLocalizations.of(context)!;` and replace:

| Line | Old | New |
|------|-----|-----|
| 167 | `'Recovered Secret'` | `l10n.restoreRecoveredSecret` |

**Important:** Steps 1-4 must all be completed before running analyze — the build will be broken between steps because `restore_screen.dart` references the old `String?` error type until Step 4 updates it.

- [ ] **Step 5: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

Fix any test failures caused by the `addShard` return type change (`String?` to `ShardError?`).

- [ ] **Step 6: Add unit tests for ShardError handling**

Create or update `banana_split_flutter/test/state/restore_notifier_test.dart` with tests for:
- `addShard` with empty QR data returns `EmptyQrError`
- `addShard` with duplicate shard returns `DuplicateShardError`
- `addShard` with invalid JSON returns `ParseError`
- `addShard` with mismatched title returns `TitleMismatchError`
- `addShard` with valid shard returns `null`

- [ ] **Step 7: Run tests again**

```bash
cd banana_split_flutter && flutter test
```

- [ ] **Step 8: Commit**

```bash
git add banana_split_flutter/lib/state/restore_notifier.dart banana_split_flutter/lib/screens/restore_screen.dart banana_split_flutter/test/
git commit -m "feat: localize restore screen with typed error handling"
```

---

### Task 8: Localize shard_scanner.dart and qr_grid.dart

**Files:**
- Modify: `banana_split_flutter/lib/widgets/shard_scanner.dart`
- Modify: `banana_split_flutter/lib/widgets/qr_grid.dart`

- [ ] **Step 1: Localize shard_scanner.dart**

Add import:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

In `build()`, add `final l10n = AppLocalizations.of(context)!;` and replace:

| Line | Old | New |
|------|-----|-----|
| 205 | `'${widget.scannedCount} of ${widget.requiredCount} scanned'` | `l10n.scannerProgress(widget.scannedCount, widget.requiredCount!)` |
| 206 | `'Scan first shard...'` | `l10n.scannerScanFirst` |
| 235-236 | `'Camera permission denied...'` | `l10n.scannerCameraDenied` |
| 240 | `'Open Settings'` | `l10n.scannerOpenSettings` |
| 249-250 | `'Camera not available...'` | `l10n.scannerCameraUnavailable` |
| 257 | `'Import from gallery'` | `l10n.scannerImportGallery` |

In `_importFromGallery()`, the snackbar on line 167 needs context-based l10n. Since this is inside an async method of a `State`, use:

```dart
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scannerNoQrFound)),
      );
    }
```

Remove `const` from `TextButton` on line 238-241 and from `Text` widgets containing l10n strings.

- [ ] **Step 2: Localize qr_grid.dart**

Add import:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

In `build()`, add `final l10n = AppLocalizations.of(context)!;` and replace:

| Line | Old | New |
|------|-----|-----|
| 29 | `'Shard ${index + 1} of ${shardJsons.length}'` | `l10n.shardLabel(index + 1, shardJsons.length)` |
| 44 | `'Save this shard'` tooltip | `l10n.shardSaveTooltip` |
| 54 | `'Shard saved'` | `l10n.shardSaved` |
| 60 | `'Error saving: $e'` | `l10n.errorSaving(e.toString())` |
| 68 | `'Share this shard'` tooltip | `l10n.shardShareTooltip` |
| 79 | `'Error sharing: $e'` | `l10n.errorSharing(e.toString())` |

- [ ] **Step 3: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
git add banana_split_flutter/lib/widgets/shard_scanner.dart banana_split_flutter/lib/widgets/qr_grid.dart
git commit -m "feat: localize scanner and QR grid widgets"
```

---

### Task 9: Localize export_service.dart PDF strings

**Files:**
- Modify: `banana_split_flutter/lib/services/export_service.dart`
- Modify: `banana_split_flutter/lib/screens/create_screen.dart` (update calls to pass localized strings)

The `ExportService` is a static utility class with no `BuildContext`. Pass pre-localized strings as parameters.

- [ ] **Step 1: Add localized string parameters to saveAsPdf**

Update `saveAsPdf` signature:

```dart
  static Future<String> saveAsPdf({
    required List<String> shardJsons,
    required String title,
    required int requiredShards,
    required String Function(int index, int total) shardLabelBuilder,
    required String requiresLabel,
    required String passphrasePlaceholder,
  }) async {
```

Replace hardcoded PDF text in the method body:

```dart
              pw.Text(shardLabelBuilder(i + 1, shardJsons.length), style: const pw.TextStyle(fontSize: 18)),
              pw.Text(requiresLabel, style: const pw.TextStyle(fontSize: 14)),
              // ...
              pw.Text(passphrasePlaceholder, style: const pw.TextStyle(fontSize: 16)),
```

- [ ] **Step 2: Update call site in create_screen.dart**

In `_ResultsView`, update the `saveAsPdf` call:

```dart
                    final l10n = AppLocalizations.of(context)!;
                    final path = await ExportService.saveAsPdf(
                      shardJsons: notifier.generatedShards,
                      title: notifier.title,
                      requiredShards: notifier.requiredShards,
                      shardLabelBuilder: (index, total) =>
                          l10n.pdfShardLabel(index, total),
                      requiresLabel: l10n.pdfRequiresShards(notifier.requiredShards),
                      passphrasePlaceholder: l10n.pdfPassphrasePlaceholder,
                    );
```

- [ ] **Step 3: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
git add banana_split_flutter/lib/services/export_service.dart banana_split_flutter/lib/screens/create_screen.dart
git commit -m "feat: localize PDF export strings"
```

---

## Chunk 3: Translation ARB Files

### Task 10: Add all translation ARB files

**Files:**
- Create: `banana_split_flutter/lib/l10n/app_ru.arb`
- Create: `banana_split_flutter/lib/l10n/app_tr.arb`
- Create: `banana_split_flutter/lib/l10n/app_be.arb`
- Create: `banana_split_flutter/lib/l10n/app_ka.arb`
- Create: `banana_split_flutter/lib/l10n/app_uk.arb`

Each ARB file must contain translations for ALL keys defined in `app_en.arb` (excluding `@@locale` and `@`-prefixed metadata entries). Metadata entries (`@keyName`) are only needed in the template file.

- [ ] **Step 1: Create app_ru.arb (Russian)**

Create `banana_split_flutter/lib/l10n/app_ru.arb` with Russian translations for all keys. Use proper Russian terminology for cryptographic concepts. Example structure:

```json
{
  "@@locale": "ru",
  "appTitle": "Banana Split",
  "tabCreate": "\u0421\u043e\u0437\u0434\u0430\u0442\u044c",
  "tabRestore": "\u0412\u043e\u0441\u0441\u0442\u0430\u043d\u043e\u0432\u0438\u0442\u044c",
  "tabAbout": "\u041e \u043f\u0440\u0438\u043b\u043e\u0436\u0435\u043d\u0438\u0438",
  ...all other keys with Russian translations...
}
```

- [ ] **Step 2: Create app_tr.arb (Turkish)**

Create `banana_split_flutter/lib/l10n/app_tr.arb` with Turkish translations.

- [ ] **Step 3: Create app_be.arb (Belarusian)**

Create `banana_split_flutter/lib/l10n/app_be.arb` with Belarusian translations.

- [ ] **Step 4: Create app_ka.arb (Georgian)**

Create `banana_split_flutter/lib/l10n/app_ka.arb` with Georgian translations.

- [ ] **Step 5: Create app_uk.arb (Ukrainian)**

Create `banana_split_flutter/lib/l10n/app_uk.arb` with Ukrainian translations.

- [ ] **Step 6: Run flutter gen-l10n and verify all locales compile**

```bash
cd banana_split_flutter && flutter gen-l10n
```

Expected: no errors, generates delegates for all 6 locales.

- [ ] **Step 7: Run flutter analyze and tests**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

- [ ] **Step 8: Commit**

```bash
git add banana_split_flutter/lib/l10n/
git commit -m "feat: add translations for RU, TR, BE, KA, UK"
```

---

### Task 11: Final verification and cleanup

**Files:**
- Possibly modify: any files with remaining hardcoded strings

- [ ] **Step 1: Grep for remaining hardcoded UI strings**

```bash
cd banana_split_flutter && grep -rn "const Text(" lib/ --include="*.dart" | grep -v "test/" | grep -v ".g.dart"
```

Any remaining `const Text('...')` with English text (not a variable) needs to be localized. Fix any found.

- [ ] **Step 2: Run full test suite**

```bash
cd banana_split_flutter && flutter analyze && flutter test
```

- [ ] **Step 3: Commit any cleanup**

```bash
git add -A && git commit -m "chore: final l10n cleanup"
```
