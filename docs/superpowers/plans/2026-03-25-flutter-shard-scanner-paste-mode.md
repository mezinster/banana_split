# Flutter ShardScanner Paste Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Paste Text" input mode to the Flutter `ShardScanner` widget so users can manually enter raw JSON shard strings as a fallback to camera/image import.

**Architecture:** Add an `_InputMode` enum to `ShardScanner`, change the `onScanned` callback to return `ShardError?`, add a paste UI with multi-line text field and submit logic that delegates all validation to `RestoreNotifier.addShard()`, and show a single summary SnackBar.

**Tech Stack:** Flutter, Dart, Provider, flutter_localizations (ARB/gen-l10n)

**Spec:** `docs/superpowers/specs/2026-03-25-flutter-shard-scanner-paste-mode-design.md`

---

### Task 1: Add i18n keys for paste mode

**Files:**
- Modify: `banana_split_flutter/lib/l10n/app_en.arb` (add 8 keys after line 57)
- Modify: `banana_split_flutter/lib/l10n/app_ru.arb`
- Modify: `banana_split_flutter/lib/l10n/app_tr.arb`
- Modify: `banana_split_flutter/lib/l10n/app_be.arb`
- Modify: `banana_split_flutter/lib/l10n/app_ka.arb`
- Modify: `banana_split_flutter/lib/l10n/app_uk.arb`

- [ ] **Step 1: Add keys to `app_en.arb`**

Add these entries after the `"scannerImportGallery"` line (line 57) in `app_en.arb`:

```json
  "scannerPasteText": "Paste text",
  "scannerBackToCamera": "Back to camera",
  "scannerPasteHint": "Paste one or more shard JSONs, one per line",
  "scannerPasteSubmit": "Submit",
  "scannerPasteEmpty": "No text to process",
  "scannerPasteAdded": "{count} shard(s) added",
  "@scannerPasteAdded": { "placeholders": { "count": { "type": "int" } } },
  "scannerPasteFailed": "{count} line(s) failed",
  "@scannerPasteFailed": { "placeholders": { "count": { "type": "int" } } },
  "scannerPasteDuplicate": "{count} duplicate(s)",
  "@scannerPasteDuplicate": { "placeholders": { "count": { "type": "int" } } },
```

- [ ] **Step 2: Add keys to all 5 non-English ARB files**

Add the same keys to `app_ru.arb`, `app_tr.arb`, `app_be.arb`, `app_ka.arb`, `app_uk.arb` with English placeholders. Add after the existing `"scannerImportGallery"` line in each file. Non-English files do NOT get `@` metadata entries (only the template file `app_en.arb` has those).

```json
  "scannerPasteText": "Paste text",
  "scannerBackToCamera": "Back to camera",
  "scannerPasteHint": "Paste one or more shard JSONs, one per line",
  "scannerPasteSubmit": "Submit",
  "scannerPasteEmpty": "No text to process",
  "scannerPasteAdded": "{count} shard(s) added",
  "scannerPasteFailed": "{count} line(s) failed",
  "scannerPasteDuplicate": "{count} duplicate(s)",
```

- [ ] **Step 3: Run `flutter gen-l10n` to regenerate localizations**

Run: `cd banana_split_flutter && flutter gen-l10n`
Expected: Clean output, no errors. Generated files updated in `.dart_tool/flutter_gen/gen_l10n/`.

- [ ] **Step 4: Verify the app still analyzes cleanly**

Run: `cd banana_split_flutter && flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add banana_split_flutter/lib/l10n/
git commit -m "feat: add i18n keys for ShardScanner paste mode"
```

---

### Task 2: Change `onScanned` callback to return `ShardError?`

This task changes the callback signature and updates all existing call sites. No new functionality yet.

**Files:**
- Modify: `banana_split_flutter/lib/widgets/shard_scanner.dart:16` (callback type)
- Modify: `banana_split_flutter/lib/widgets/shard_scanner.dart:215-242` (camera call sites)
- Modify: `banana_split_flutter/lib/widgets/shard_scanner.dart:256-344` (gallery call site)
- Modify: `banana_split_flutter/lib/screens/restore_screen.dart:67-99` (_ScannerView)

- [ ] **Step 1: Change the callback type in `ShardScanner`**

In `banana_split_flutter/lib/widgets/shard_scanner.dart`, change line 16 from:

```dart
  final void Function(String rawData) onScanned;
```

to:

```dart
  final ShardError? Function(String rawData, {bool isBatch}) onScanned;
```

Add import at top of file (after line 6):

```dart
import 'package:banana_split_flutter/state/restore_notifier.dart';
```

- [ ] **Step 2: Update `_onDetect` (mobile camera) — lines 215-229**

Change the method to use the return value and only add to `_seenCodes` on success:

```dart
  void _onDetect(BarcodeCapture capture) {
    if (_disposed) return;

    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 500) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      if (_seenCodes.contains(raw)) continue;

      _lastScanTime = now;
      final error = widget.onScanned(raw);
      if (error == null) {
        _seenCodes.add(raw);
      }
    }
  }
```

- [ ] **Step 3: Update `_onQrDetected` (Windows camera) — lines 232-243**

```dart
  void _onQrDetected(String raw) {
    if (_disposed) return;
    if (raw.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 500) return;
    if (_seenCodes.contains(raw)) return;

    _lastScanTime = now;
    final error = widget.onScanned(raw);
    if (error == null) {
      _seenCodes.add(raw);
    }
  }
```

- [ ] **Step 4: Update `_importFromGallery` — lines 314-321**

Replace the dedup/call block inside the `for (final filePath in filePaths)` loop (the section after the fallback zxing decode). Change from:

```dart
        // Skip throttle — dedup via _seenCodes only (no camera rapid-fire here)
        if (raw != null && raw.isNotEmpty && !_seenCodes.contains(raw)) {
          _seenCodes.add(raw);
          widget.onScanned(raw);
          decoded++;
        } else if (raw == null) {
          failed++;
        }
```

to:

```dart
        if (raw != null && raw.isNotEmpty) {
          final error = widget.onScanned(raw);
          if (error == null) {
            _seenCodes.add(raw);
            decoded++;
          } else if (error is DuplicateShardError) {
            // Already scanned — don't count as failed
          } else {
            failed++;
          }
        } else {
          failed++;
        }
```

- [ ] **Step 5: Update `RestoreScreen._ScannerView` — lines 78-97**

In `banana_split_flutter/lib/screens/restore_screen.dart`, change the `onScanned` callback in `_ScannerView.build()`:

```dart
      onScanned: (rawData, {isBatch = false}) {
        final error = notifier.addShard(rawData);
        if (!isBatch) {
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
        }
        return error;
      },
```

- [ ] **Step 6: Verify analyze passes**

Run: `cd banana_split_flutter && flutter analyze`
Expected: No issues found.

- [ ] **Step 7: Run existing tests**

Run: `cd banana_split_flutter && flutter test test/state/restore_notifier_test.dart`
Expected: All tests pass (callback change doesn't affect notifier tests).

- [ ] **Step 8: Commit**

```bash
git add banana_split_flutter/lib/widgets/shard_scanner.dart banana_split_flutter/lib/screens/restore_screen.dart
git commit -m "refactor: change ShardScanner onScanned to return ShardError?"
```

---

### Task 3: Add paste mode UI and submit logic to `ShardScanner`

**Files:**
- Modify: `banana_split_flutter/lib/widgets/shard_scanner.dart`

- [ ] **Step 1: Add `_InputMode` enum and mode state**

Add the enum before the `ShardScanner` class (after imports, before line 15):

```dart
enum _InputMode { camera, paste }
```

Add to `_ShardScannerState` fields (after line 47):

```dart
  _InputMode _mode = _InputMode.camera;
  final TextEditingController _pasteController = TextEditingController();
```

Add `_pasteController.dispose()` in `dispose()` before `super.dispose()` (line 63):

```dart
    _pasteController.dispose();
```

Add a listener in `initState()` after the existing `_initCamera()` call (line 55) to enable live submit button reactivity while typing:

```dart
    _pasteController.addListener(() {
      if (_mode == _InputMode.paste) setState(() {});
    });
```

- [ ] **Step 2: Add lifecycle guard in `_retryCamera`**

Change `_retryCamera()` (line 83-87) to:

```dart
  void _retryCamera() {
    if (_disposed || _permissionDenied) return;
    if (_mode == _InputMode.paste) return;
    if (_cameraSupported) return; // already working
    _initCamera();
  }
```

- [ ] **Step 3: Add mode switching methods**

Add these methods after `_retryCamera()`:

```dart
  void _switchToPaste() {
    _disposeCamera();
    setState(() => _mode = _InputMode.paste);
  }

  void _switchToCamera() {
    _pasteController.clear();
    setState(() => _mode = _InputMode.camera);
    _initCamera();
  }
```

- [ ] **Step 4: Add paste submit method**

Add this method after the mode switching methods:

```dart
  void _submitPaste() {
    final text = _pasteController.text;
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (lines.isEmpty) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scannerPasteEmpty)),
        );
      }
      return;
    }

    int added = 0;
    int failed = 0;
    int duplicate = 0;

    for (final line in lines) {
      final error = widget.onScanned(line, isBatch: true);
      if (error == null) {
        _seenCodes.add(line);
        added++;
      } else if (error is DuplicateShardError) {
        duplicate++;
      } else {
        failed++;
      }
    }

    // Build summary SnackBar
    final l10n = AppLocalizations.of(context)!;
    final parts = <String>[];
    if (added > 0) parts.add(l10n.scannerPasteAdded(added));
    if (failed > 0) parts.add(l10n.scannerPasteFailed(failed));
    if (duplicate > 0) parts.add(l10n.scannerPasteDuplicate(duplicate));

    if (parts.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.join(', '))),
      );
    }

    // Clear on full success
    if (failed == 0 && duplicate == 0) {
      _pasteController.clear();
    }
  }
```

- [ ] **Step 5: Update `build()` to support both modes**

Replace the entire `build()` method (starting at line 384) with:

```dart
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progressText = widget.requiredCount != null
        ? l10n.scannerProgress(widget.scannedCount, widget.requiredCount!)
        : l10n.scannerScanFirst;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(progressText,
              style: Theme.of(context).textTheme.titleMedium),
        ),

        if (_mode == _InputMode.camera) ...[
          if (_cameraSupported)
            _buildCameraPreview()
          else if (_permissionDenied)
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.scannerCameraDenied),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: openAppSettings,
                    child: Text(l10n.scannerOpenSettings),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.scannerCameraUnavailable,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _retryCamera,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.scannerRetryCamera),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _importFromGallery,
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.scannerImportGallery),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _switchToPaste,
                icon: const Icon(Icons.content_paste),
                label: Text(l10n.scannerPasteText),
              ),
            ],
          ),
        ],

        if (_mode == _InputMode.paste) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _pasteController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: l10n.scannerPasteHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _switchToCamera,
                icon: const Icon(Icons.camera_alt),
                label: Text(l10n.scannerBackToCamera),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _pasteController.text.trim().isNotEmpty
                    ? _submitPaste
                    : null,
                icon: const Icon(Icons.check),
                label: Text(l10n.scannerPasteSubmit),
              ),
            ],
          ),
        ],
      ],
    );
  }
```

**Note:** The submit button reactivity relies on the `_pasteController` listener added in Step 1, which calls `setState` on each keystroke in paste mode.

- [ ] **Step 6: Verify analyze passes**

Run: `cd banana_split_flutter && flutter analyze`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add banana_split_flutter/lib/widgets/shard_scanner.dart
git commit -m "feat: add paste text mode to ShardScanner widget"
```

---

### Task 4: Write widget tests for paste mode

**Files:**
- Create: `banana_split_flutter/test/widgets/shard_scanner_paste_test.dart`

- [ ] **Step 1: Create the test file**

Create `banana_split_flutter/test/widgets/shard_scanner_paste_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:banana_split_flutter/state/restore_notifier.dart';
import 'package:banana_split_flutter/widgets/shard_scanner.dart';

/// Wraps ShardScanner in a MaterialApp with localizations for testing.
Widget _buildTestApp({
  required ShardError? Function(String, {bool isBatch}) onScanned,
  int scannedCount = 0,
  int? requiredCount,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ShardScanner(
          onScanned: onScanned,
          scannedCount: scannedCount,
          requiredCount: requiredCount,
        ),
      ),
    ),
  );
}

void main() {
  group('ShardScanner paste mode', () {
    testWidgets('tapping Paste Text shows text field and submit button',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        onScanned: (_, {isBatch = false}) => null,
        requiredCount: 3,
      ));
      await tester.pumpAndSettle();

      // Find and tap the Paste Text button
      final pasteBtn = find.text('Paste text');
      expect(pasteBtn, findsOneWidget);
      await tester.tap(pasteBtn);
      await tester.pumpAndSettle();

      // Paste mode UI should be visible
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Back to camera'), findsOneWidget);
      // Camera buttons should be gone
      expect(find.text('Import from gallery'), findsNothing);
    });

    testWidgets('tapping Back to Camera returns to camera mode',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        onScanned: (_, {isBatch = false}) => null,
        requiredCount: 3,
      ));
      await tester.pumpAndSettle();

      // Switch to paste
      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();
      expect(find.text('Submit'), findsOneWidget);

      // Switch back
      await tester.tap(find.text('Back to camera'));
      await tester.pumpAndSettle();

      // Camera mode UI should be back
      expect(find.text('Import from gallery'), findsOneWidget);
      expect(find.text('Paste text'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('valid single-line paste triggers onScanned once',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_buildTestApp(
        onScanned: (raw, {isBatch = false}) {
          calls.add(raw);
          return null; // success
        },
        requiredCount: 3,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();

      // Enter a valid shard JSON
      await tester.enterText(
        find.byType(TextField),
        '{"v":2,"t":"test","r":3,"d":"abc","n":"xyz"}',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(calls.length, 1);
      expect(calls.first, '{"v":2,"t":"test","r":3,"d":"abc","n":"xyz"}');
    });

    testWidgets('valid multi-line paste triggers onScanned per line',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_buildTestApp(
        onScanned: (raw, {isBatch = false}) {
          calls.add(raw);
          return null;
        },
        requiredCount: 3,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        '{"v":2,"t":"a","r":2,"d":"x","n":"y"}\n{"v":2,"t":"a","r":2,"d":"z","n":"y"}',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(calls.length, 2);
    });

    testWidgets('empty input shows error SnackBar, no onScanned call',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_buildTestApp(
        onScanned: (raw, {isBatch = false}) {
          calls.add(raw);
          return null;
        },
        requiredCount: 3,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();

      // Enter whitespace-only text (non-empty string so submit button is enabled,
      // but all lines are empty after trimming → triggers scannerPasteEmpty path)
      await tester.enterText(find.byType(TextField), '   \n  \n  ');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Should show "No text to process" SnackBar
      expect(find.text('No text to process'), findsOneWidget);
      expect(calls.isEmpty, true);
    });

    testWidgets('failed parse shows error in summary SnackBar',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        onScanned: (raw, {isBatch = false}) {
          return const ParseError('Invalid shard JSON');
        },
        requiredCount: 3,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'not json at all');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Should show "1 line(s) failed" SnackBar
      expect(find.textContaining('failed'), findsOneWidget);
    });

    testWidgets('duplicate shard counted in summary', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_buildTestApp(
        onScanned: (raw, {isBatch = false}) {
          callCount++;
          if (callCount > 1) return const DuplicateShardError();
          return null;
        },
        requiredCount: 3,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();

      // Paste same shard twice
      const shard = '{"v":2,"t":"test","r":3,"d":"abc","n":"xyz"}';
      await tester.enterText(find.byType(TextField), '$shard\n$shard');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(callCount, 2); // Both lines sent to onScanned
      // Should show "1 shard(s) added, 1 duplicate(s)" SnackBar
      expect(find.textContaining('added'), findsOneWidget);
      expect(find.textContaining('duplicate'), findsOneWidget);
    });

    testWidgets('isBatch is true for paste submissions', (tester) async {
      bool? receivedBatch;
      await tester.pumpWidget(_buildTestApp(
        onScanned: (raw, {isBatch = false}) {
          receivedBatch = isBatch;
          return null;
        },
        requiredCount: 3,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste text'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        '{"v":2,"t":"test","r":3,"d":"abc","n":"xyz"}',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(receivedBatch, true);
    });
  });
}
```

- [ ] **Step 2: Run the test**

Run: `cd banana_split_flutter && flutter test test/widgets/shard_scanner_paste_test.dart`
Expected: All 7 tests pass.

**Note:** These tests create a real `ShardScanner` widget. On CI or environments without a camera, the camera init will silently fail (caught by the existing try/catch), and the widget will show the "Camera not available" state. The paste mode tests don't depend on camera functionality, so they should pass regardless. If camera init causes issues in the test environment, the test will still work because paste mode disposes the camera immediately.

- [ ] **Step 3: Run all existing tests to check for regressions**

Run: `cd banana_split_flutter && sh tests/run_all.sh`
Expected: All tests pass. The callback signature change in Task 2 doesn't affect `restore_notifier_test.dart` (it tests the notifier directly, not through the widget).

- [ ] **Step 4: Run analyze**

Run: `cd banana_split_flutter && flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add banana_split_flutter/test/widgets/shard_scanner_paste_test.dart
git commit -m "test: add widget tests for ShardScanner paste mode"
```

---

### Task 5: Update CLAUDE.md and final verification

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update CLAUDE.md**

In the Flutter app's `### Architecture` section, find the `**Services**` paragraph. Before it, add or update the ShardScanner description. Find the line that mentions `ShardScanner` (it's in the `**UI**` paragraph) and update it to mention the paste mode. The current text reads:

> `ShardScanner` (platform-conditional: `mobile_scanner` on Android/iOS, `camera` package + periodic `takePicture()` + `zxing2` decode on Windows)

Update to:

> `ShardScanner` (platform-conditional camera: `mobile_scanner` on Android/iOS, `camera` package + periodic `takePicture()` + `zxing2` decode on Windows; also supports multi-file gallery import and paste text mode for manual JSON shard entry)

- [ ] **Step 2: Run full test suite**

Run: `cd banana_split_flutter && sh tests/run_all.sh`
Expected: All tests pass.

- [ ] **Step 3: Run analyze**

Run: `cd banana_split_flutter && flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document ShardScanner paste mode in CLAUDE.md"
```
