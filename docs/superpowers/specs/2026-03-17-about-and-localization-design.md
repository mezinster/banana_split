# About Screen Enhancements & App Localization — Design Spec

## Goal

Enhance the About screen with version display, privacy policy, and license information, then make the entire app multilingual with support for English, Russian, Turkish, Belarusian, Georgian, and Ukrainian.

## Part 1: About Screen Enhancements

### Version Display

- Show "Version X.Y.Z (Build N)" at the bottom of the About screen.
- Use `package_info_plus` to read the installed app version and build number at runtime.
- Load version info via `FutureBuilder<PackageInfo>` wrapping `PackageInfo.fromPlatform()`. Show an empty `SizedBox` while loading.
- CI release workflow already injects version/build into pubspec.yaml, so this reflects the real release version.

### Privacy Policy

- Create `PRIVACY_POLICY.md` in the repo root with the full privacy policy text.
- Content: The app performs all cryptographic operations on-device. No data is transmitted to any server. No analytics, no tracking, no accounts. Shards and secrets never leave the device unless the user explicitly exports/shares them.
- Add a new `PrivacyPolicyScreen` widget (`lib/screens/privacy_policy_screen.dart`).
- The in-app privacy policy text comes from localized ARB strings (translated per locale). The `PRIVACY_POLICY.md` file in the repo is the English-only reference copy for GitHub viewing.
- A "View online" button at the top links to `https://github.com/mezinster/banana_split/blob/master/PRIVACY_POLICY.md` via `url_launcher`.
- The About screen gets a tappable `ListTile` that navigates to `PrivacyPolicyScreen`.

### Licenses

- Add a tappable `ListTile` on the About screen labeled "Open-source licenses".
- Tapping it calls Flutter's built-in `showLicensePage()` which auto-collects all third-party package licenses.
- The app's own GPLv3 license is registered via `LicenseRegistry.addLicense()` in `main.dart` so it appears prominently in the license page. This API takes a callback returning a `Stream<LicenseEntry>` — use `Stream.value(LicenseEntryWithLineBreaks(['Banana Split'], licenseText))`.
- The `applicationName`, `applicationVersion`, and `applicationIcon` parameters are passed to `showLicensePage()` for branding.

### New Dependencies

- `package_info_plus` — read installed version/build number at runtime.
- `url_launcher` — open privacy policy URL in external browser.

### About Screen Layout (updated)

Current content stays as-is (SSS explanation, how it works, security notes), with the following additions at the bottom:

1. Divider
2. Version text: "Version X.Y.Z (Build N)"
3. ListTile: "Privacy Policy" → navigates to `PrivacyPolicyScreen`
4. ListTile: "Open-source licenses" → calls `showLicensePage()`

## Part 2: Localization

### Framework

Flutter's official localization system:
- `flutter_localizations` (SDK dependency)
- `intl` package for message extraction/formatting
- ARB files with code generation via `flutter gen-l10n`

### Configuration

**pubspec.yaml additions:**
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

**l10n.yaml** (project root of `banana_split_flutter/`):
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

### ARB Files

Located in `banana_split_flutter/lib/l10n/`:

| File | Language | Locale Code |
|------|----------|-------------|
| `app_en.arb` | English | en |
| `app_ru.arb` | Russian | ru |
| `app_tr.arb` | Turkish | tr |
| `app_be.arb` | Belarusian | be |
| `app_ka.arb` | Georgian | ka |
| `app_uk.arb` | Ukrainian | uk |

`app_en.arb` is the template file. All translation keys are defined here first. Other ARB files provide translations for each key.

### Locale Resolution

- `MaterialApp.localizationsDelegates` includes `AppLocalizations.delegate`, `GlobalMaterialLocalizations.delegate`, `GlobalWidgetsLocalizations.delegate`, and `GlobalCupertinoLocalizations.delegate`.
- `MaterialApp.supportedLocales` lists all six locales.
- System locale is detected automatically. Falls back to English for unsupported locales.
- No in-app language picker — the OS setting controls the language.

**Note on Georgian (ka) and Belarusian (be):** Flutter's `GlobalMaterialLocalizations` may not include built-in delegates for these locales. If they are missing, the Material widgets (date pickers, dialogs, etc.) will fall back to English while app-level strings from `AppLocalizations` will still display correctly in Georgian/Belarusian. This is acceptable — the app does not use date pickers or other locale-sensitive Material widgets.

### Scope of Translatable Strings

All hardcoded user-facing text across the app:

**Navigation:**
- Tab labels: "Create", "Restore", "About"
- App title: "Banana Split"

**Create Screen:**
- Field labels: "Title", "Secret", "Total shards", "Required to restore"
- Hints: "e.g. My wallet seed phrase", "Enter the secret to split", "3-255", "2-N"
- Helper/error text: "X of Y shards needed to restore", "Secret exceeds 1024 characters", "X/1024 characters"
- Passphrase field labels and buttons
- Button: "Generate QR Shards"
- Results view: "Save your passphrase!", passphrase instructions, "Back", tooltips

**Restore Screen:**
- Scanner progress: "X of Y scanned", "Scan first shard..."
- Permission/camera messages
- Button: "Import from gallery"
- Passphrase entry labels
- Success/error messages

**About Screen:**
- All explanatory text (SSS description, how it works, security notes)
- "Privacy Policy" and "Open-source licenses" labels
- Version display format

**Privacy Policy Screen:**
- Title: "Privacy Policy"
- "View online" button label
- Full privacy policy body text

**Snackbar messages:**
- "Saved to $path", "Error saving: $e", "Error sharing: $e"
- "No QR code found in image"
- "This shard has already been scanned" (if still present)

### Usage Pattern

Before:
```dart
const Text('Generate QR Shards')
```

After:
```dart
Text(AppLocalizations.of(context)!.generateButton)
```

### Translation Key Naming Convention

- camelCase with screen name as prefix: `createTitle`, `createSecretLabel`, `restoreScanProgress`, `aboutPrivacyPolicy`
- Shared/global keys have no prefix: `appTitle`, `errorSaving`, `back`
- Parameterized strings use ICU message syntax: `"{count} of {total} scanned"`

## Files Created or Modified

### New Files
- `PRIVACY_POLICY.md` — repo root
- `lib/screens/privacy_policy_screen.dart` — inline privacy policy display
- `lib/l10n/app_en.arb` — English (template)
- `lib/l10n/app_ru.arb` — Russian
- `lib/l10n/app_tr.arb` — Turkish
- `lib/l10n/app_be.arb` — Belarusian
- `lib/l10n/app_ka.arb` — Georgian
- `lib/l10n/app_uk.arb` — Ukrainian
- `l10n.yaml` — localization config (in `banana_split_flutter/`)

### Modified Files
- `pubspec.yaml` — add `flutter_localizations`, `intl`, `package_info_plus`, `url_launcher`, `generate: true`
- `lib/main.dart` — add localization delegates, supported locales, GPLv3 license registration; refactor `_destinations` from `static const` to built inside `build()` (localized labels require `BuildContext`)
- `lib/screens/about_screen.dart` — add version display, privacy policy tile, licenses tile
- `lib/screens/create_screen.dart` — replace hardcoded strings with `AppLocalizations` calls
- `lib/screens/restore_screen.dart` — replace hardcoded strings with `AppLocalizations` calls
- `lib/widgets/shard_scanner.dart` — replace hardcoded strings with `AppLocalizations` calls
- `lib/widgets/passphrase_field.dart` — replace hardcoded strings with `AppLocalizations` calls
- `lib/widgets/qr_grid.dart` — replace "Shard X of Y", tooltips, snackbar messages with `AppLocalizations` calls
- `lib/services/export_service.dart` — replace hardcoded strings if any user-facing text exists

## Out of Scope

- In-app language picker (follow system locale)
- RTL layout support (none of the 6 target languages are RTL)
- Date/number formatting differences (not used in current UI)
- Translating the wordlist (passphrase words stay English — they're cryptographic, not UI)
