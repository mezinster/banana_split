# Web App Parity & PDF Unicode Fonts — Design Spec

## Goal

Bring the web app to feature parity with the Flutter app on two key user-facing controls (custom passphrase, selectable quorum), and fix corrupted non-Latin text in Flutter PDF exports.

## Scope

Three independent changes that share the goal of cross-app compatibility:

1. **Web app: custom passphrase** — add auto/manual toggle for recovery passphrase
2. **Web app: selectable quorum** — let users pick how many shards are required
3. **Flutter app: PDF Unicode fonts** — bundle Roboto + Noto Sans Georgian for correct rendering

---

## 1. Web App: Custom Passphrase

### Current State

`Share.vue` auto-generates a 4-word passphrase on component creation via `passPhrase.generate(4)`. The passphrase is displayed as canvas-rendered text (`CanvasText` component) with a regenerate button. There is no way to enter a custom passphrase. The passphrase UI appears only after clicking "Generate QR codes".

### Design

**Move passphrase to the form area** (before the Generate button) so users configure everything before generating.

**Add `useManualPassphrase: boolean`** to component data (default: `false`).

**Auto mode** (default):
- Show auto-generated 4-word passphrase via `CanvasText` with regenerate button (current behavior)

**Manual mode**:
- Show a text `<input>` bound to `recoveryPassphrase`
- Minimum 8 characters validation
- When toggling back to auto: regenerate a new 4-word passphrase

**Toggle**: Checkbox labeled "Use custom passphrase" below the passphrase display. Disabled in encryption mode (like all other form inputs).

**Encryption mode behavior**: The passphrase toggle and input are disabled when in encryption mode, matching the existing pattern where `title`, `secret`, and `totalShards` are all disabled. Since the passphrase section is now in the form area (before the Generate button), it naturally participates in the same disable logic.

**Validation**: Disable "Generate QR codes" button if manual mode and `recoveryPassphrase.length < 8`.

**Print output**: The passphrase is shown in cleartext (not masked) since this is a recovery passphrase the user needs to write on each shard page. The existing print layout in `ShardQrCode.vue` shows a blank "Recovery passphrase is ___" line — this is unchanged regardless of auto/manual mode.

### Files Changed

- `src/views/Share.vue` — add toggle, manual input, validation, restructure passphrase section

### Files NOT Changed

- `src/util/crypto.ts` — `share()` already accepts any string passphrase
- `src/util/passPhrase.ts` — no changes needed

---

## 2. Web App: Selectable Quorum

### Current State

`Share.vue` has a computed property `requiredShards` that returns `Math.floor(totalShards / 2) + 1`. The user can only change `totalShards`; the quorum is auto-calculated and displayed as static text.

### Design

**Convert `requiredShards` from computed to data property** (initial value: 2).

**Add a watcher on `totalShards`** that resets `requiredShards` to `Math.floor(totalShards / 2) + 1` whenever total changes — sensible default, but user can override.

**Add a number input** for `requiredShards`:
- `type="number"`, `min="2"`, `:max="totalShards"`
- Disabled in encryption mode
- Template becomes: `Will require any [input] shards out of [input] to reconstruct`

**Clamping**: When `requiredShards` exceeds `totalShards`, clamp it down. When below 2, clamp up. Applied via watcher or input handler.

**`totalShards` minimum remains 3** (unchanged from current behavior). With `totalShards >= 3` and `requiredShards >= 2`, the valid range for quorum is always 2 to totalShards.

### Files Changed

- `src/views/Share.vue` — convert computed to data, add watcher, add input

### Files NOT Changed

- `src/util/crypto.ts` — `share()` already accepts `requiredShards` as a parameter

---

## 3. Flutter App: PDF Unicode Fonts

### Current State

`export_service.dart` uses the `pdf` package (v3.11.1) with default fonts (Helvetica). Helvetica has no glyphs for Cyrillic, Georgian, or other non-Latin scripts. PDFs with Russian, Georgian, etc. text render corrupted characters.

### Design

**Bundle three TTF font files as assets:**
- `assets/fonts/Roboto-Regular.ttf` (~170KB) — Latin, Cyrillic (RU/BE/UK), Greek, Turkish
- `assets/fonts/Roboto-Bold.ttf` (~170KB) — bold variant for PDF title rendering
- `assets/fonts/NotoSansGeorgian-Regular.ttf` (~50KB) — Georgian script

**Update `pubspec.yaml`**: add both TTFs to the flutter assets list.

**Update `export_service.dart`**:
- Add a `String languageCode` parameter to `saveAsPdf()`
- Load the appropriate TTF from assets: `languageCode == 'ka'` → Noto Sans Georgian, else → Roboto
- Create `pw.Font.ttf()` from the loaded byte data for both regular and bold variants
- Pass the font via `pw.TextStyle(font: regularFont)` to body text and `pw.TextStyle(font: boldFont)` to the title
- For Georgian: use regular weight for both (no bold variant bundled — acceptable trade-off for ~50KB savings)

**Font selection limitation (accepted trade-off)**: Font is chosen by UI locale, not by text content analysis. A user in English locale typing a Georgian title would get Roboto (which lacks Georgian glyphs). This is acceptable because: (a) users typing in Georgian will almost certainly have the Georgian locale active, (b) content-based font detection adds significant complexity for a rare edge case.

**Update the call site** (in `create_screen.dart` or wherever `saveAsPdf` is invoked): pass the current locale's language code from the app's locale state.

### Files Changed

- `banana_split_flutter/assets/fonts/Roboto-Regular.ttf` — new asset
- `banana_split_flutter/assets/fonts/Roboto-Bold.ttf` — new asset
- `banana_split_flutter/assets/fonts/NotoSansGeorgian-Regular.ttf` — new asset
- `banana_split_flutter/pubspec.yaml` — add font assets
- `banana_split_flutter/lib/services/export_service.dart` — load font, accept language code
- `banana_split_flutter/lib/screens/create_screen.dart` — pass language code to export

---

## Testing

### Web App

- Existing `crypto.spec.ts` tests cover `share()` and `reconstruct()` — no changes needed since the crypto layer is untouched.
- Add a unit test: `share()` with a custom passphrase round-trips through `reconstruct()`.
- Manual testing: verify custom passphrase encrypts/decrypts correctly, verify quorum values are passed through to shards correctly.

### Flutter App

- Existing test suite covers crypto round-trips — no changes needed.
- Manual testing: generate a PDF with Russian title/passphrase placeholder, verify Cyrillic text is readable. Test with Belarusian and Ukrainian locales to confirm full Cyrillic coverage. Test with Georgian locale to verify Noto Sans Georgian rendering.

---

## Cross-App Compatibility

No shard format changes. All three features are UI/presentation changes only. The crypto protocol is unchanged — shards from either app remain fully interoperable.
