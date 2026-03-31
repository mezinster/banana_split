# F-Droid Publishing Preparation — Design Spec

**Date:** 2026-03-31
**Status:** Approved
**App ID:** `com.nfcarchiver.banana_split`

## Context

Banana Split Flutter is a fork of [paritytech/banana_split](https://github.com/paritytech/banana_split) by Parity Technologies. It is released under GPLv3. For F-Droid publishing, we need to: change the placeholder application ID, add proper derivative work attribution, create F-Droid metadata, and declare anti-features.

## 1. Application ID Change

**From:** `com.example.banana_split_flutter`
**To:** `com.nfcarchiver.banana_split`

### Files to modify

| File | Change |
|------|--------|
| `banana_split_flutter/android/app/build.gradle` | `namespace` and `applicationId` → `com.nfcarchiver.banana_split` |
| `banana_split_flutter/android/app/src/main/AndroidManifest.xml` | No change needed (uses relative `.MainActivity`, namespace comes from Gradle) |
| `banana_split_flutter/android/app/src/main/kotlin/com/example/banana_split_flutter/MainActivity.kt` | Move to `com/nfcarchiver/banana_split/MainActivity.kt`, update `package` declaration |

The old `com/example/banana_split_flutter/` directory tree is deleted after the move.

**Note:** Changing application ID means this is a **new app** to Android. Users of any previous debug builds would need to uninstall and reinstall. Since this is pre-release (no F-Droid or Play Store listing yet), this has no impact.

## 2. GPLv3 Derivative Work Attribution

GPLv3 Section 5 requires prominent notice that the work is modified and carries a relevant date. Attribution goes in three places:

### 2a. README.md — Fork Notice Section

Add immediately after the badges, before the first paragraph:

```markdown
> **Fork Notice:** This project is a fork of [banana_split](https://github.com/paritytech/banana_split) originally developed by [Parity Technologies](https://www.parity.io/). Original work © 2019–2020 Parity Technologies. This fork © 2026 Evgeny Mezin. Licensed under [GPLv3](LICENSE).
```

### 2b. About Screen

Add a new section between the Security Notes and the Divider, containing:
- Text: "This app is a fork of banana_split by Parity Technologies" (localized)
- Tappable link to `https://github.com/paritytech/banana_split`
- Copyright line: "Original work © 2019–2020 Parity Technologies. This fork © 2026 Evgeny Mezin."

This requires new i18n keys in all 7 ARB files:
- `aboutForkNotice` — "This app is a fork of {repoName} by {author}."
- `aboutForkCopyright` — "Original work © 2019–2020 Parity Technologies. This fork © 2026 Evgeny Mezin."
- `aboutSourceCode` — "Source Code"

The source code link (`https://github.com/mezinster/banana_split`) should also be added as a tappable ListTile, since F-Droid users expect to find the source link in the About page.

### 2c. NOTICE File

Create `NOTICE` at repo root (standard GPL companion file):

```
Banana Split
Copyright © 2026 Evgeny Mezin

This program is a derivative work (fork) of:
  banana_split — https://github.com/paritytech/banana_split
  Copyright © 2019–2020 Parity Technologies (UK) Ltd.

Both the original work and this derivative are licensed under the
GNU General Public License v3.0. See the LICENSE file for details.
```

## 3. Fastlane Metadata Directory

F-Droid reads app metadata from the fastlane directory structure. Screenshots are deferred to a later phase.

### Directory structure

```
banana_split_flutter/fastlane/metadata/android/
├── en-US/
│   ├── title.txt            — "Banana Split"
│   ├── short_description.txt — max 80 chars
│   ├── full_description.txt  — max 4000 chars
│   └── changelogs/
│       └── 1.txt             — changelog for versionCode 1
├── ru/
│   ├── title.txt
│   ├── short_description.txt
│   ├── full_description.txt
│   └── changelogs/
│       └── 1.txt
├── tr/
│   └── ... (same structure)
├── be/
│   └── ...
├── ka/
│   └── ...
├── uk/
│   └── ...
└── pl/
    └── ...
```

### Content

**short_description.txt (en-US):**
> Split secrets into QR-code shards using Shamir's Secret Sharing

**full_description.txt (en-US):**
Derived from the README — covers what the app does, how splitting/reconstructing works, why it's useful, and key features (offline, open source, cross-platform shard compatibility). Mentions the fork origin and GPLv3 license.

**changelogs/1.txt:**
Derived from CHANGELOG.md entry for v0.8.0 (current versionCode 1).

Translations for all 7 locales (en, ru, tr, be, ka, uk, pl).

## 4. Anti-Features Declaration

`mobile_scanner` uses Google ML Kit (proprietary) on Android. Declare this openly.

### .fdroid.yml

Create at `banana_split_flutter/.fdroid.yml`:

```yaml
AntiFeatures:
  NonFreeDep:
    en-US: |
      Uses Google ML Kit (via mobile_scanner package) for QR code scanning.
      ML Kit is a proprietary Google library bundled in the APK.
      A pure open-source alternative (zxing2) is used on Windows/Linux.
```

### F-Droid categories

```yaml
Categories:
  - Security
  - Connectivity
  - System
```

## 5. pubspec.yaml Description

**From:** `"A new Flutter project."`
**To:** `"Split secrets into QR-code shards using Shamir's Secret Sharing. Offline, open-source, cross-platform."`

## 6. Version Code Strategy

F-Droid uses `versionCode` (the `+N` in pubspec.yaml) to track updates. Current: `0.8.0+1`.

For future releases, the versionCode must be incremented monotonically. The existing release workflow already handles this via `--build-number`. Each new release should add a corresponding `changelogs/<versionCode>.txt` file in the fastlane metadata.

## 7. Items Explicitly Deferred

- **Screenshots** — will be added later to `fastlane/metadata/android/<locale>/images/phoneScreenshots/`
- **Feature graphic** — `featureGraphic.png` (1024×500) for F-Droid listing header
- **fdroiddata merge request** — the actual submission to [gitlab.com/fdroid/fdroiddata](https://gitlab.com/fdroid/fdroiddata) with the build recipe
- **Reproducible builds** — optional F-Droid feature, not required for initial listing
- **Replacing mobile_scanner with FOSS alternative** — accepted as NonFreeDep anti-feature for now

## Summary of All Files Changed/Created

### New files
- `NOTICE` (repo root)
- `banana_split_flutter/.fdroid.yml`
- `banana_split_flutter/fastlane/metadata/android/en-US/title.txt`
- `banana_split_flutter/fastlane/metadata/android/en-US/short_description.txt`
- `banana_split_flutter/fastlane/metadata/android/en-US/full_description.txt`
- `banana_split_flutter/fastlane/metadata/android/en-US/changelogs/1.txt`
- (Same structure for ru, tr, be, ka, uk, pl locales)
- `banana_split_flutter/android/app/src/main/kotlin/com/nfcarchiver/banana_split/MainActivity.kt`

### Modified files
- `banana_split_flutter/android/app/build.gradle` — applicationId + namespace
- `banana_split_flutter/pubspec.yaml` — description
- `banana_split_flutter/lib/screens/about_screen.dart` — fork attribution + source code link
- `banana_split_flutter/lib/l10n/app_en.arb` — new i18n keys (+ all 6 translation ARBs)
- `README.md` — fork notice section

### Deleted files
- `banana_split_flutter/android/app/src/main/kotlin/com/example/banana_split_flutter/MainActivity.kt` (moved)
