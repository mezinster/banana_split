# Web App Parity & PDF Unicode Fonts — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add custom passphrase and selectable quorum to the web app, and fix non-Latin font rendering in Flutter PDF exports.

**Architecture:** Web app changes are purely in `Share.vue` — adding form controls and converting a computed property to data. Flutter changes bundle TTF font assets and load them in the PDF export service.

**Tech Stack:** Vue 2 + TypeScript (web), Flutter/Dart with `pdf` package (mobile), Google Fonts (Roboto, Noto Sans Georgian)

---

## Chunk 1: Web App Changes

### Task 1: Add selectable quorum to Share.vue

**Files:**
- Modify: `src/views/Share.vue:31-44` (template), `src/views/Share.vue:99-145` (script)

- [ ] **Step 1: Convert `requiredShards` from computed to data, add watcher**

In `src/views/Share.vue`, update the `ShareData` type to add `requiredShards`:

```typescript
type ShareData = {
  title: string;
  secret: string;
  totalShards: number;
  requiredShards: number;
  recoveryPassphrase: string;
  encryptionMode: boolean;
};
```

Move `requiredShards` from `computed` to `data()` with initial value `2`:

```typescript
data(): ShareData {
  return {
    title: "",
    secret: "",
    totalShards: 3,
    requiredShards: 2,
    recoveryPassphrase: "",
    encryptionMode: false
  };
},
```

Remove `requiredShards` from `computed`.

Add a `watch` section:

```typescript
watch: {
  totalShards(newVal: number) {
    this.requiredShards = Math.floor(newVal / 2) + 1;
  }
},
```

- [ ] **Step 2: Add quorum number input to template**

Replace the shards paragraph (lines 31-44) with:

```html
<p>
  <label>3. Shards</label>
  <br />
  Will require any
  <input
    id="requiredShards"
    v-model.number="requiredShards"
    :disabled="encryptionMode"
    type="number"
    min="2"
    :max="totalShards"
  />
  shards out of
  <input
    id="totalShards"
    v-model.number="totalShards"
    :disabled="encryptionMode"
    type="number"
    min="3"
    max="255"
  />
  to reconstruct
</p>
```

- [ ] **Step 3: Run web unit tests**

Run: `yarn test:unit`
Expected: All existing tests pass (crypto layer unchanged).

- [ ] **Step 4: Commit**

```bash
git add src/views/Share.vue
git commit -m "feat(web): add selectable quorum to Share view"
```

---

### Task 2: Add custom passphrase toggle to Share.vue

**Files:**
- Modify: `src/views/Share.vue` (template + script)

- [ ] **Step 1: Add `useManualPassphrase` to data and update type**

Add to `ShareData`:
```typescript
type ShareData = {
  title: string;
  secret: string;
  totalShards: number;
  requiredShards: number;
  recoveryPassphrase: string;
  useManualPassphrase: boolean;
  encryptionMode: boolean;
};
```

Add to `data()`:
```typescript
useManualPassphrase: false,
```

- [ ] **Step 2: Move passphrase section into form, add toggle and manual input**

Move the passphrase section from the `v-if="encryptionMode"` block (lines 65-74) into the form card (before the Generate button). Replace with:

```html
<p>
  <label>4. Recovery passphrase</label>
  <div v-if="!useManualPassphrase" class="flex justify-between align-center">
    <canvas-text :text="recoveryPassphrase" />
    <button class="button-icon" @click="regenPassphrase" :disabled="encryptionMode">
      &#x21ba;
    </button>
  </div>
  <div v-else>
    <input
      id="manualPassphrase"
      v-model="recoveryPassphrase"
      type="text"
      :disabled="encryptionMode"
      placeholder="Enter passphrase (min 8 characters)"
    />
    <span v-if="passphraseTooShort" class="error-text">
      Passphrase must be at least 8 characters
    </span>
  </div>
  <label class="checkbox-label">
    <input
      type="checkbox"
      v-model="useManualPassphrase"
      :disabled="encryptionMode"
      @change="onPassphraseToggle"
    />
    Use custom passphrase
  </label>
</p>
```

- [ ] **Step 3: Add validation computed and toggle method**

Add to `computed`:
```typescript
passphraseTooShort(): boolean {
  return this.useManualPassphrase && this.recoveryPassphrase.length < 8;
},
```

Update `generateDisabled` logic — the Generate button `:disabled` should check both conditions:
```html
:disabled="secretTooLong || passphraseTooShort"
```

Add to `methods`:
```typescript
onPassphraseToggle: function() {
  if (!this.useManualPassphrase) {
    this.regenPassphrase();
  } else {
    this.recoveryPassphrase = "";
  }
},
```

- [ ] **Step 4: Add CSS for checkbox label**

```css
.checkbox-label {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
  cursor: pointer;
  font-weight: normal;
}
```

- [ ] **Step 5: Run web unit tests**

Run: `yarn test:unit`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/views/Share.vue
git commit -m "feat(web): add custom passphrase toggle with auto/manual modes"
```

---

## Chunk 2: Flutter PDF Font Fix

### Task 3: Bundle fonts and update PDF export service

**Files:**
- Create: `banana_split_flutter/assets/fonts/Roboto-Regular.ttf`
- Create: `banana_split_flutter/assets/fonts/Roboto-Bold.ttf`
- Create: `banana_split_flutter/assets/fonts/NotoSansGeorgian-Regular.ttf`
- Modify: `banana_split_flutter/pubspec.yaml`
- Modify: `banana_split_flutter/lib/services/export_service.dart`
- Modify: `banana_split_flutter/lib/screens/create_screen.dart:258-270`

- [ ] **Step 1: Download font files**

Download from Google Fonts:
- Roboto Regular: `https://github.com/google/fonts/raw/main/ofl/roboto/Roboto%5Bwdth%2Cwght%5D.ttf` — extract Regular weight
- Roboto Bold: same source, Bold weight
- Noto Sans Georgian: `https://github.com/google/fonts/raw/main/ofl/notosansgeorgian/NotoSansGeorgian%5Bwdth%2Cwght%5D.ttf`

Alternative: download static TTF files from https://fonts.google.com/

Save to `banana_split_flutter/assets/fonts/`.

- [ ] **Step 2: Add font assets to pubspec.yaml**

In `banana_split_flutter/pubspec.yaml`, add to the flutter assets list:

```yaml
  assets:
    - assets/wordlist.txt
    - assets/app_icon.png
    - assets/fonts/Roboto-Regular.ttf
    - assets/fonts/Roboto-Bold.ttf
    - assets/fonts/NotoSansGeorgian-Regular.ttf
```

- [ ] **Step 3: Update export_service.dart to load and use custom fonts**

Add `import 'package:flutter/services.dart';` at the top.

Add a `String languageCode` parameter to `saveAsPdf()`.

Load fonts before the PDF loop:

```dart
static Future<String> saveAsPdf({
  required List<String> shardJsons,
  required String title,
  required int requiredShards,
  required String Function(int index, int total) shardLabelBuilder,
  required String requiresLabel,
  required String passphrasePlaceholder,
  String languageCode = 'en',
}) async {
  // Load fonts
  final pw.Font regularFont;
  final pw.Font boldFont;
  if (languageCode == 'ka') {
    final fontData = await rootBundle.load('assets/fonts/NotoSansGeorgian-Regular.ttf');
    regularFont = pw.Font.ttf(fontData);
    boldFont = regularFont; // No bold variant for Georgian
  } else {
    final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    regularFont = pw.Font.ttf(regularData);
    boldFont = pw.Font.ttf(boldData);
  }
  // ... rest of method
```

Update all `pw.Text` widgets to use the loaded fonts:

```dart
pw.Text(title, style: pw.TextStyle(fontSize: 24, font: boldFont, fontWeight: pw.FontWeight.bold)),
// ...
pw.Text(shardLabelBuilder(i + 1, shardJsons.length), style: pw.TextStyle(fontSize: 18, font: regularFont)),
pw.Text(requiresLabel, style: pw.TextStyle(fontSize: 14, font: regularFont)),
// ...
pw.Text(passphrasePlaceholder, style: pw.TextStyle(fontSize: 16, font: regularFont)),
```

- [ ] **Step 4: Update create_screen.dart call site to pass languageCode**

In `create_screen.dart`, at the `saveAsPdf` call (~line 262), add the languageCode parameter:

```dart
final path = await ExportService.saveAsPdf(
  shardJsons: notifier.generatedShards,
  title: notifier.title,
  requiredShards: notifier.requiredShards,
  shardLabelBuilder: (index, total) =>
      l10n.pdfShardLabel(index, total),
  requiresLabel: l10n.pdfRequiresShards(notifier.requiredShards),
  passphrasePlaceholder: l10n.pdfPassphrasePlaceholder,
  languageCode: Localizations.localeOf(context).languageCode,
);
```

- [ ] **Step 5: Run Flutter tests**

Run: `cd banana_split_flutter && flutter test`
Expected: All existing tests pass.

- [ ] **Step 6: Commit**

```bash
git add banana_split_flutter/assets/fonts/ banana_split_flutter/pubspec.yaml \
  banana_split_flutter/lib/services/export_service.dart \
  banana_split_flutter/lib/screens/create_screen.dart
git commit -m "feat(flutter): bundle Roboto and Noto Sans Georgian for PDF Unicode support"
```
