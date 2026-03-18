# Web App Internationalization (i18n) Design

## Goal

Add multilingual support to the Vue 2 web app, matching the Flutter app's 6 supported languages (EN, RU, TR, BE, KA, UK) using vue-i18n v8.

## Requirements

- Same 6 languages as the Flutter app: English, Russian, Turkish, Belarusian, Georgian, Ukrainian
- Flag-based dropdown language switcher in the header (same UX pattern as Flutter app)
- Auto-detect language from `navigator.language` on load, default to English
- No persistence — each visit detects from browser, user can override for the session
- All UI text translated, including the GeneralInfo explanatory content
- Print output language selectable independently from UI language at print time
- Translations ported from existing Flutter ARB files where keys overlap

## Architecture

### i18n Library

**vue-i18n v8** (compatible with Vue 2), installed via yarn. Configured as a Vue plugin in a new `src/i18n.ts` module. Single i18n instance with:
- `locale`: detected from `navigator.language`, falling back to `'en'`
- `fallbackLocale`: `'en'`
- All 6 locale message objects loaded eagerly (the app builds to a single inlined HTML file, so lazy-loading provides no benefit)
- Custom `pluralizationRules` for Russian, Ukrainian, and Belarusian (Slavic languages have 3 plural forms: one, few, many) and Georgian

### Locale Files

```
src/locales/
  en.json
  ru.json
  tr.json
  be.json
  ka.json
  uk.json
```

Flat camelCase keys grouped by feature prefix, mirroring Flutter ARB naming:
```json
{
  "appTitle": "Banana Split",
  "tabCreate": "Create",
  "tabRestore": "Restore",
  "createSecretLabel": "2. Secret",
  "createCharCounter": "{remaining} / 1024 characters remaining",
  "shardNeedMore": "You need {count} more QR code to reconstruct the secret | You need {count} more QR codes to reconstruct the secret"
}
```

- Interpolation: `$t('createCharCounter', { remaining: 1024 - secret.length })`
- Pluralization: `$tc('shardNeedMore', count, { count })` — English uses 2 pipe-separated forms (singular|plural), Slavic locales use 3 forms (one|few|many)

### Pluralization Rules

vue-i18n v8's default pluralization is the English two-form rule. Custom `pluralizationRules` must be configured for:
- **ru, uk, be** — Slavic plural rules: `1` → form 0, `2-4` → form 1, `5-20` and `0` → form 2, then cycle
- **ka** — Georgian typically uses a single form (no grammatical plural distinction for numbers), but a custom rule is added for correctness
- **tr** — Turkish also uses a single form in most contexts

These are set in the `VueI18n` constructor options.

### Translation Sources

Translations are ported from the existing Flutter ARB files where keys overlap. The web app has some unique strings (GeneralInfo paragraphs, print-specific text) — these are ported from Flutter `about*` and `pdf*` ARB keys where content matches, and freshly translated where they don't.

### HTML in Translations

GeneralInfo.vue contains paragraphs with inline HTML (links like `<a href="...">Shamir's secret sharing</a>`). These are handled using vue-i18n's `<i18n>` component interpolation (not `v-html`, to avoid XSS risks):

```html
<i18n path="infoHowToUseStep1" tag="li">
  <template #link>
    <router-link to="/share">{{ $t('tabCreate') }}</router-link>
  </template>
</i18n>
```

Translation strings use `{link}` placeholders for the HTML slot positions.

## Components

### Language Switcher (`src/components/LanguageSelector.vue`)

Flag-based dropdown in the header area of App.vue. Displays the current locale's flag as the trigger button. On click, shows the full list:

| Locale | Display |
|--------|---------|
| en | English |
| ru | Русский |
| tr | Turkce |
| be | Беларуская |
| ka | ქართული |
| uk | Українська |

Changing selection sets `this.$i18n.locale`, reactively updating all `$t()` calls. Hidden in print via `@media print { display: none }`.

**Note on flag emoji:** Windows does not render country flag emoji (shows two-letter codes instead). Consider using small inline SVG flags for cross-platform consistency, or accept the two-letter fallback on Windows as adequate since the language name is also shown.

### Language Detection (`src/i18n.ts`)

On app load:
1. Read `navigator.language` (e.g., `"ru-RU"`)
2. Extract language code (`"ru"`)
3. Match against supported locales: `['en', 'ru', 'tr', 'be', 'ka', 'uk']`
4. If matched, use it. Otherwise default to `'en'`

### HTML lang Attribute

A watcher on `$i18n.locale` in App.vue updates `document.documentElement.lang` to match the current locale. This improves accessibility (screen readers) and semantic correctness.

### Print Language Selector

A small flag-based dropdown appears next to the "Print us!" button in Share.vue when shards are generated (encryption mode). It defaults to the current UI language.

- Stored as `printLocale` data on Share.vue — does NOT change the main UI language
- Passed as a prop through `ShardInfo.vue` → `ShardQrCode.vue`
- `ShardQrCode.vue` uses vue-i18n's 3-argument locale override: `$t('key', printLocale, { count })` for simple strings, and `$tc('key', count, printLocale, { count })` for pluralized strings

**Translated print strings:**
- "You need X more QR codes to reconstruct the secret" (pluralized)
- "Recovery passphrase is ___"
- "Please go to nfcarchiver.com/banana/ to download..."
- "This has been generated by BananaSplit version..."

## File Changes

### Modified Files

| File | Changes |
|------|---------|
| `main.ts` | Import vue-i18n, create i18n instance, pass to Vue |
| `App.vue` | Add `<language-selector>` in header, replace "Banana Split" with `$t()`, add `html lang` watcher |
| `Share.vue` | Replace ~20 strings with `$t()`, add `printLocale` + print language dropdown |
| `Combine.vue` | Replace ~14 strings with `$t()`, including error strings emitted via `$eventHub` |
| `Print.vue` | Replace ~11 strings with `$t()`, including error strings emitted via `$eventHub` |
| `Info.vue` | Replace nav button labels with `$t()` |
| `GeneralInfo.vue` | Replace all headings and paragraphs with `$t()` and `<i18n>` component for HTML content (~11 keys) |
| `ShardQrCode.vue` | Accept `locale` prop, use `$t(key, locale, params)` and `$tc()` for printed text |
| `ShardInfo.vue` | Pass i18n instance to detached Vue instance (`new Vue({ i18n: this.$root.$i18n, ... })`), forward `locale` prop to ShardQrCode |
| `ForkMe.vue` | Replace "Fork me on GitHub" with `$t()` |

### New Files

| File | Purpose |
|------|---------|
| `src/i18n.ts` | i18n instance setup with locale detection and pluralization rules |
| `src/components/LanguageSelector.vue` | Flag-based dropdown component |
| `src/locales/en.json` | English translations (~75-80 keys) |
| `src/locales/ru.json` | Russian translations |
| `src/locales/tr.json` | Turkish translations |
| `src/locales/be.json` | Belarusian translations |
| `src/locales/ka.json` | Georgian translations |
| `src/locales/uk.json` | Ukrainian translations |

### Unchanged Files

- `src/util/crypto.ts` — no user-facing strings
- `src/util/passPhrase.ts` — no user-facing strings
- `vue.config.js` — JSON imports are statically resolved and inlined by webpack
- `src/components/Alert.vue` — displays dynamic messages passed to it, no hardcoded strings
- `src/components/CanvasText.vue` — text passed as prop

### Key Implementation Detail: ShardInfo.vue

`ShardInfo.vue` creates a detached Vue instance with `new Vue({ el, render })` to mount `ShardQrCode` into the `#print` DOM node. This detached instance does NOT inherit the i18n plugin from the root Vue instance. It must be modified to:
1. Inject the i18n instance: `new Vue({ el, i18n: this.$root.$i18n, render })`
2. Accept and forward the `locale` prop to ShardQrCode

Without this, all `$t()` calls inside ShardQrCode would fail at runtime.

## Testing

- Existing unit tests (crypto round-trips) are unaffected — no UI strings involved
- Test environment configures `locale: 'en'` so `$t()` calls resolve deterministically
- E2E tests (Playwright) use CSS selectors (`#shareNav`, `#generateBtn`) not text content, so they are largely unaffected. Ensure locale defaults to `en` in test setup.

## Font Considerations

Georgian (KA) uses the Mkhedruli script, which may not be available in the system font stack on all platforms. The web app does not bundle fonts (unlike the Flutter app which bundles Roboto and Noto Sans Georgian). Georgian rendering depends on the user's OS having a Georgian-capable font installed. Consider adding `"Noto Sans Georgian"` to the CSS `font-family` fallback chain (without bundling the font file, since it would bloat the single-HTML build).

## Approximate String Count

~75-80 translatable keys per locale file, including:
- UI controls: ~25 (buttons, labels, headings)
- Form text: ~18 (placeholders, validation, hints)
- Error/status messages: ~12
- GeneralInfo content: ~11 (headings + paragraphs)
- Print/shard text: ~8
- System text: ~3 (version, links)
