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
- SnackBar feedback (summary only, suppress per-shard SnackBars from RestoreScreen during batch paste)
- i18n keys for all 6 locales
- Widget tests for paste mode
- Minor `RestoreScreen` change: add `isBatch` flag to suppress per-shard SnackBars during paste submission

**Out of scope:**
- Changes to `RestoreNotifier` or `Shard` model
- Changes to `CreateScreen`
- Changes to camera or gallery import behavior

## Design

### Mode State

`ShardScanner` gains a `_mode` enum field:

```dart
enum _InputMode { camera, paste }
```

Default is `_InputMode.camera`. Switching modes disposes/reinits the camera to save resources and avoid lifecycle issues.

### Lifecycle Guard

The existing `didChangeAppLifecycleState` handler calls `_retryCamera()` on app resume. When in paste mode, camera reinit must be skipped. Add a guard:

```dart
if (_mode == _InputMode.paste) return;
```

at the top of `_retryCamera()`, alongside the existing `_disposed` and `_isPickingFile` guards.

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
3. If no non-empty lines: show `scannerPasteEmpty` SnackBar, return
4. For each non-empty line, call `widget.onScanned(line)` unconditionally — let `RestoreNotifier.addShard()` handle all validation and deduplication. Collect the returned `ShardError?` from each call.
5. Count results: success (null return), duplicate (`DuplicateShardError`), failed (any other error)
6. Show a single summary SnackBar with counts
7. On full success: clear the text field
8. On partial success or all-failure: keep text field contents so user can fix bad lines

**Deduplication ownership:** `RestoreNotifier.addShard()` is the authoritative duplicate detector (via its `_rawCodes` set). Paste mode does NOT pre-filter with ShardScanner's `_seenCodes`. However, successfully added shards are still added to `_seenCodes` so that camera mode can deduplicate against them later.

### Callback Change

To support batch paste, `ShardScanner`'s `onScanned` callback changes from `void Function(String)` to `ShardError? Function(String)` — returning the error from `RestoreNotifier.addShard()` (or null on success). This allows paste mode to collect results per line and build the summary SnackBar.

`RestoreScreen._ScannerView` updates its callback to return the error:

```dart
onScanned: (rawData) {
  final error = notifier.addShard(rawData);
  if (error != null) {
    // Show per-shard SnackBar (existing behavior, camera/gallery only)
  }
  return error;
},
```

In paste mode, ShardScanner calls `onScanned` per line but handles the SnackBar itself (summary), so RestoreScreen's per-shard SnackBars are not triggered — the summary SnackBar is shown by ShardScanner after all lines are processed.

**Suppressing per-shard SnackBars:** Add an optional `bool isBatch` parameter to the `onScanned` callback signature: `ShardError? Function(String rawData, {bool isBatch})`. Camera/gallery calls pass `isBatch: false` (default). Paste mode calls pass `isBatch: true`. RestoreScreen skips per-shard SnackBars when `isBatch` is true.

### Data Flow

```
Paste text → split lines → onScanned(line, isBatch: true) per line
                           ↓
                    RestoreNotifier.addShard()
                    (validates, deduplicates, returns ShardError?)
                           ↓
                    ShardScanner collects errors
                           ↓
                    Single summary SnackBar
```

### i18n

New ARB keys (following existing `scanner*` convention):

| Key | English Value | Metadata |
|-----|---------------|----------|
| `scannerPasteText` | "Paste text" | — |
| `scannerBackToCamera` | "Back to camera" | — |
| `scannerPasteHint` | "Paste one or more shard JSONs, one per line" | — |
| `scannerPasteSubmit` | "Submit" | — |
| `scannerPasteEmpty` | "No text to process" | — |
| `scannerPasteAdded` | "{count} shard(s) added" | `@` with `count: int` |
| `scannerPasteFailed` | "{count} line(s) failed" | `@` with `count: int` |
| `scannerPasteDuplicate` | "{count} duplicate(s)" | `@` with `count: int` |

The summary SnackBar is built in Dart by joining the non-zero parts with ", " — e.g., "2 shard(s) added, 1 line(s) failed". This avoids a single parameterized string that shows "0 failed, 0 duplicate" when there are no errors.

English gets real translations. Other 5 locales (RU, TR, BE, KA, UK) get English placeholders.

Run `flutter gen-l10n` after editing ARB files to regenerate `AppLocalizations`.

### Testing

Widget tests for the paste mode. Tests verify behavior by asserting widget presence/absence and callback invocations (not internal `_mode` state, which is library-private).

1. **Mode switching** — tapping "Paste Text" shows text field and submit button; tapping "Back to Camera" hides them
2. **Valid single-line paste** — triggers `onScanned` once, returns null (success)
3. **Valid multi-line paste** — triggers `onScanned` per valid line
4. **Invalid JSON** — `onScanned` returns `ParseError`, shows error SnackBar summary
5. **Empty input** — shows "No text to process" SnackBar, does not call `onScanned`
6. **Duplicate detection** — `onScanned` returns `DuplicateShardError`, counted in summary

### Files Modified

- `lib/widgets/shard_scanner.dart` — add `_InputMode` enum, paste mode UI, submit logic, lifecycle guard, callback type change
- `lib/screens/restore_screen.dart` — update `onScanned` callback to return `ShardError?`, add `isBatch` parameter handling
- `lib/l10n/app_en.arb` — add 8 new keys with `@` metadata (template)
- `lib/l10n/app_ru.arb` — add 8 new keys (English placeholders)
- `lib/l10n/app_tr.arb` — add 8 new keys (English placeholders)
- `lib/l10n/app_be.arb` — add 8 new keys (English placeholders)
- `lib/l10n/app_ka.arb` — add 8 new keys (English placeholders)
- `lib/l10n/app_uk.arb` — add 8 new keys (English placeholders)
- `test/shard_scanner_paste_test.dart` — new test file for paste mode
