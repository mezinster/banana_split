# ShardInput: Multi-Method Shard Input Component

**Date:** 2026-03-25
**Status:** Approved
**Scope:** Web app (Vue 2 + TypeScript)

## Problem

The web app's Combine and Print pages only support camera-based QR scanning via `vue-qrcode-reader`. Dense QR codes (version 23, 817 bytes) can be unreliable when scanned from paper via a webcam, even though the QR data is valid. Users need fallback input methods.

## Solution

A new `<ShardInput>` component that encapsulates three input methods:
1. **Camera** (existing `qrcode-stream`, default)
2. **Upload image** (multi-file, decoded with jsqr)
3. **Paste text** (multi-JSON, parsed directly)

The component emits `decode(result: string)` — the same interface as `qrcode-stream` — so parent views require minimal changes.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Pages affected | Both Combine and Print | Both use identical camera-only scanning |
| UX pattern | Camera default + fallback buttons below | Minimal disruption to existing flow |
| Image upload | Multi-file selection | Batch decode multiple shard photos at once |
| Text paste | Multi-JSON support | Paste all shards scanned by external app |
| QR decode library | Existing jsqr | Already bundled, proven on these QR codes |
| Architecture | Shared component (Approach 2) | Clean encapsulation, same @decode contract |

## Component Design

### File

`src/components/ShardInput.vue`

### Interface

```html
<ShardInput @decode="onDecode" />
```

Emits `decode(result: string)` once per successfully decoded shard. For multi-image or multi-paste, emits multiple times. Parent views' `onDecode` methods remain unchanged.

### Internal State

- `mode: 'camera' | 'upload' | 'paste'` — active input method, defaults to `'camera'`
- `feedback: { type: 'success' | 'error', message: string } | null` — inline status message

### Layout

```
+--------------------------------+
| [Active input area]            |
|   Camera feed (mode=camera)    |
|   File results (mode=upload)   |
|   Textarea (mode=paste)        |
+--------------------------------+
| [Button A]  |  [Button B]      |  <- the other two modes
+--------------------------------+
```

The two fallback buttons always show the two non-active modes. Styled as `button-card` text links.

## Image Upload Flow

1. Hidden `<input type="file" accept="image/*" multiple>` triggered by "Upload image" button
2. Per image:
   a. `FileReader.readAsDataURL()`
   b. Create `Image()`, wait for `onload`
   c. Draw onto temporary `<canvas>`
   d. Extract `ImageData` (RGBA pixels)
   e. `jsqr(imageData.data, width, height)`
   f. If decoded: emit `decode(result)`
   g. If failed: collect as error
3. Show inline feedback:
   - All success: "Decoded {success} of {total} images" (auto-clears ~2s)
   - Partial: "Decoded {success} of {total} images. {fail} could not be read."
   - All fail: "Could not decode QR code from image." (persists)

jsqr is imported directly from `node_modules/jsqr` (already bundled via `vue-qrcode-reader`).

## Paste Text Flow

1. Multi-line textarea with placeholder "Paste shard JSON here..."
2. "Submit" button triggers parsing
3. Parser finds all `{...}` balanced JSON objects in the input text
4. For each candidate: `JSON.parse()`, if valid emit `decode(jsonString)`
5. Inline feedback (same pattern as image upload):
   - All success: "Parsed {success} of {total} shards" (auto-clears)
   - Partial: "Parsed {success} of {total} entries. {fail} not valid."
   - All fail: "No valid shard JSON found." (persists)
6. Textarea clears after successful submission

## Localization

New i18n keys added to all 6 locale files (`en.json` + RU, TR, BE, KA, UK):

```json
"inputUploadImage": "Upload image",
"inputPasteText": "Paste text",
"inputUseCamera": "Use camera",
"inputPastePlaceholder": "Paste shard JSON here...",
"inputPasteSubmit": "Submit",
"inputDecodeSuccess": "Decoded {success} of {total} images",
"inputDecodeFail": "Could not decode QR code from image",
"inputDecodePartial": "Decoded {success} of {total} images. {fail} could not be read.",
"inputParseSuccess": "Parsed {success} of {total} shards",
"inputParseFail": "No valid shard JSON found",
"inputParsePartial": "Parsed {success} of {total} entries. {fail} not valid."
```

English gets real translations. Other 5 locales get English placeholders for now.

## View Changes

**Combine.vue and Print.vue:**
- Replace `<qrcode-stream @decode="onDecode" />` with `<ShardInput @decode="onDecode" />`
- Add `ShardInput` to component imports
- Remove `.qrcode-stream` CSS (moves into ShardInput)
- All `onDecode` methods, data properties, and validation logic remain untouched

## Styling

- Fallback buttons: existing `button-card` style, row layout below active input
- Camera feed: keeps `scaleX(-1)` mirror transform, `border-radius: 8px` (moved into ShardInput)
- Feedback text: inline status line, green for success, red for errors
- Textarea: matches existing input/textarea styles from App.vue

## Edge Cases

| Case | Handling |
|------|----------|
| Camera permission denied | Handled by `qrcode-stream` internally |
| Non-image files | `accept="image/*"` prevents at OS level; fallback: "could not decode" |
| Empty paste | "No valid shard JSON found", no emit |
| Duplicate shards | Parent's `onDecode` handles via `qrCodes.has(result)` check |
| Large images | Canvas draws at original size; jsqr handles large images fine |
| Mode switching | Already-scanned shards preserved in parent; only input method changes |

## Out of Scope

- Drag-and-drop file upload
- Camera device selection
- Offline QR detection improvements
