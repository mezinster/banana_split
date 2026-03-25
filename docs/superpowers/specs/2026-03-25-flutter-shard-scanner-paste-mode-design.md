# Flutter ShardScanner Paste Mode Design

## Goal

Add a "Paste Text" input mode to the Flutter app's `ShardScanner` widget, allowing users to manually paste raw JSON shard strings as a fallback when camera scanning or image import aren't practical. This brings the Flutter app to feature parity with the web app's `ShardInput` component.

## Context

The web app recently gained three shard entry modes (camera, image upload, paste text) via the `ShardInput` component. The Flutter app's `ShardScanner` already supports camera scanning and multi-file image import. Only the paste text mode is missing.

## Scope

**In scope:**
- Add paste text mode to `ShardScanner` widget
- Mode switching UI (camera ↔ paste)
- Multi-line JSON paste with per-line parsing
- SnackBar feedback (success/fail/duplicate counts)
- i18n keys for all 6 locales
- Widget tests for paste mode

**Out of scope:**
- Changes to `RestoreScreen`, `RestoreNotifier`, or `Shard` model
- Changes to `CreateScreen`
- Changes to camera or gallery import behavior
- New widgets or files (all changes within existing `ShardScanner`)

## Design

### Mode State

`ShardScanner` gains a `_mode` enum field:

```dart
enum _InputMode { camera, paste }
```

Default is `_InputMode.camera`. Switching modes disposes/reinits the camera to save resources and avoid lifecycle issues.

### Camera Mode (existing + new button)

Camera mode works exactly as today. The button row below the camera preview gains a second button:

- "Import from gallery" (existing)
- "Paste Text" (new) — switches to paste mode

Both buttons use the same visual style (existing outlined button pattern).

### Paste Mode

When the user taps "Paste Text":

1. Camera is disposed
2. UI shows:
   - Multi-line `TextField` (5-6 visible lines) with hint text: "Paste one or more shard JSONs, one per line"
   - "Submit" button — disabled when text field is empty/whitespace
   - "Back to Camera" button — reinitializes camera and returns to camera mode

### Paste Submit Logic

On submit:

1. Split text by newlines
2. Trim each line, skip empty lines
3. For each non-empty line:
   - Check if already in `_seenCodes` set → count as duplicate
   - Attempt `Shard.parse(line)` to validate JSON structure
   - If valid and not duplicate: call `widget.onScanned(line)`, add to `_seenCodes`, count as success
   - If parse fails: count as failed
4. Show SnackBar with results:
   - All success: "N shard(s) added"
   - All failed: "N line(s) failed to parse"
   - Mixed: "N added, M failed"
   - Duplicates included in count: "N added, M failed, K duplicate"
   - Empty input: "No text to process"
5. On full success: clear the text field
6. On partial success or all-failure: keep text field contents so user can fix bad lines

### Data Flow

The `onScanned` callback is reused for all three input methods. `RestoreScreen` receives shard strings identically regardless of source — no changes needed upstream.

```
Paste text → split lines → Shard.parse() validation → onScanned(line) per valid shard
                                                     ↓
                                              RestoreNotifier.addShard()
                                              (same path as camera/gallery)
```

### i18n

New ARB keys (following existing `scanner*` convention):

| Key | English Value |
|-----|---------------|
| `scannerPasteText` | "Paste text" |
| `scannerBackToCamera` | "Back to camera" |
| `scannerPasteHint` | "Paste one or more shard JSONs, one per line" |
| `scannerPasteSubmit` | "Submit" |
| `scannerPasteEmpty` | "No text to process" |
| `scannerPasteResults` | "{added} added, {failed} failed, {duplicate} duplicate" |

English gets real translations. Other 5 locales (RU, TR, BE, KA, UK) get English placeholders.

### Testing

Widget tests for the paste mode (no camera dependencies):

1. **Mode switching** — tapping "Paste Text" shows text field, tapping "Back to Camera" hides it
2. **Valid single-line paste** — triggers `onScanned` once
3. **Valid multi-line paste** — triggers `onScanned` per valid line
4. **Invalid JSON** — shows error SnackBar, does not trigger `onScanned`
5. **Empty input** — shows "No text to process" SnackBar
6. **Duplicate detection** — second paste of same shard counted as duplicate

### Files Modified

- `lib/widgets/shard_scanner.dart` — add `_InputMode` enum, paste mode UI, submit logic
- `lib/l10n/app_en.arb` — add 6 new keys (template)
- `lib/l10n/app_ru.arb` — add 6 new keys (English placeholders)
- `lib/l10n/app_tr.arb` — add 6 new keys (English placeholders)
- `lib/l10n/app_be.arb` — add 6 new keys (English placeholders)
- `lib/l10n/app_ka.arb` — add 6 new keys (English placeholders)
- `lib/l10n/app_uk.arb` — add 6 new keys (English placeholders)
- `test/shard_scanner_paste_test.dart` — new test file for paste mode

### No Files Created (except test)

All production code changes are within existing files. One new test file is needed since `ShardScanner` doesn't have existing widget tests (camera dependency makes them impractical, but paste mode is pure UI + parsing).
