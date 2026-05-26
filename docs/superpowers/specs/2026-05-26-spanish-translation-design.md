# Spanish (es) Translation — Design Spec

**Date:** 2026-05-26
**Issue:** https://github.com/mezinster/banana_split/issues/2
**Branch:** `feature/issue-2-spanish-translation`

## Goal

Add Spanish (`es`) as a supported locale across all three delivery targets: the Vue 2 web app, the Flutter Android app, and the Flutter Windows app. The translation will use generic `es` (not a country-specific variant) with formal register, represented by 🇪🇸 in the language picker.

## Scope

### Web app (`src/`)

| File | Change |
|------|--------|
| `src/locales/es.json` | **New.** 69 keys translated from `en.json`. |
| `src/i18n.ts` | Import `es.json`; add `"es"` to `SUPPORTED_LOCALES` array and `messages` object. |
| `src/components/LanguageSelector.vue` | Add `{ code: "es", flag: "🇪🇸", name: "Español" }` to the `LOCALES` array. |

No custom pluralization rule: Spanish uses standard 2-form plural (1 = singular, else = plural), which vue-i18n handles by default.

### Flutter app (`banana_split_flutter/`)

| File | Change |
|------|--------|
| `lib/l10n/app_es.arb` | **New.** All keys from `app_en.arb` translated. `@@locale: "es"`. Placeholder metadata entries (`@key`) carried through unchanged. |
| `lib/widgets/language_selector.dart` | Add `(locale: Locale('es'), flag: '🇪🇸', name: 'Español')` to `_localeData`. |

`flutter gen-l10n` auto-discovers `app_es.arb` — no changes to `l10n.yaml` or `pubspec.yaml`.

## Translation notes

- **Register:** Formal (`usted`), consistent with a security/crypto context.
- **Long-form strings** (privacy policy body, about text, how-it-works paragraphs) are translated in full — they appear in the Flutter About screen and web Info tab.
- **Placeholders** (`{count}`, `{title}`, etc.) are preserved verbatim; surrounding text is translated.
- **Plural strings** (web app uses `|`-separated forms): Spanish needs exactly 2 forms — `singular | plural`.

## Out of scope

- Fastlane changelogs: no new `versionCode` is bumped in this branch.
- Any new UI strings: translation only, no feature additions.

## Verification

- Web: `yarn lint` passes; browser auto-detects `es` on a Spanish-language system.
- Flutter: `flutter gen-l10n` succeeds (no missing keys); `flutter analyze` clean; `sh tests/run_all.sh` passes.
