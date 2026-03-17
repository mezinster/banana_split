# Files Tab & App Icon Design

## Goal

1. Add a "Files" tab to the app that lets users browse, share, and delete saved PDFs/PNGs.
2. Replace the default Flutter icon with the Banana Split logo on Android and Windows.

---

## Feature 1: Files Tab

### Overview

A 4th tab "Files" in the bottom navigation bar. Lists all files saved by the export service from `getApplicationDocumentsDirectory()/banana_split/`. Users can share or delete files directly.

### FilesScreen (`lib/screens/files_screen.dart`)

- Files are displayed as a flat list sorted by last modified date (newest first).
- Each entry shows: filename, file size (human-readable), and last modified date (formatted via `DateFormat.yMMMd()` which auto-localizes).
- Note: PNGs are saved into title subdirectories (`banana_split/{title}/`) but PDFs are saved directly into `banana_split/`. The file list scans recursively and displays all files regardless of nesting depth. The parent directory name is shown as a subtitle for files inside subdirectories to provide context.
- Each file has two action buttons:
  - **Share** — uses `share_plus` (`Share.shareXFiles`) to share via OS share sheet.
  - **Delete** — shows a confirmation dialog, then deletes the file. If the parent directory becomes empty after deletion, it is also removed. On failure, shows a snackbar with error message.
- **Empty state**: centered message when no files exist (e.g., "No saved files. Create shards and save them to see files here.").
- **Refresh**: pull-to-refresh (`RefreshIndicator`) to reload the file list.
- Files are loaded by scanning `getApplicationDocumentsDirectory()/banana_split/` recursively for `.png` and `.pdf` files.

### State Management

No dedicated notifier needed. `FilesScreen` is a `StatefulWidget` that loads the file list in `initState()` and on pull-to-refresh. The file list is local state (`List<FileSystemEntity>`).

### Navigation Integration

- `HomeShell` in `main.dart`: add a 4th `NavigationDestination` between Restore and About (position index 2), with icon `Icons.folder_outlined` / `Icons.folder`, label from `l10n.tabFiles`. Tab order becomes: Create, Restore, Files, About.
- Add `FilesScreen()` to the `_screens` list at index 2. The `_screens` list must change from `static const` to `static const` with a `const FilesScreen()` constructor, or to a non-const list if `FilesScreen` cannot be const.

### Localization

New ARB keys (all 6 languages):
- `tabFiles` — "Files" tab label
- `filesEmpty` — empty state message
- `filesDeleteConfirmTitle` — "Delete file?"
- `filesDeleteConfirmBody` — "This will permanently delete {filename}."
- `filesDeleteButton` — "Delete"
- `filesCancelButton` — "Cancel"
- `filesDeleted` — "File deleted"
- `filesShareError` — "Error sharing file"
- `filesDeleteError` — "Error deleting file"

### Dependencies

No new dependencies. Uses existing `path_provider`, `share_plus`, `intl` (for date formatting).

### Platform Notes

Works identically on Android and Windows. Both platforms use `getApplicationDocumentsDirectory()` which maps to the app's scoped storage.

---

## Feature 2: App Icon

### Source Image

`/mnt/c/Users/Evgeny_Mezin/Downloads/Banana_Split.png` — 1024x1536 RGBA PNG. Two bananas splitting open to reveal QR codes, with "Banana" text below.

### Processing Pipeline

1. **Pad to square**: Use ImageMagick to pad 1024x1536 to 1536x1536 (centered, transparent background). Save as `assets/app_icon.png` in the Flutter project.
2. **Generate icons**: Use `flutter_launcher_icons` package (added as dev dependency) to generate all required sizes.
3. **Clean up**: Remove `flutter_launcher_icons` from dev dependencies AND the `flutter_launcher_icons:` config block from `pubspec.yaml` after generation (one-time tool).

### Configuration

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: false
  windows:
    generate: true
    image_path: "assets/app_icon.png"
  image_path: "assets/app_icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/app_icon.png"
```

### Android Output

- `ic_launcher.png` in mipmap-mdpi (48x48), mipmap-hdpi (72x72), mipmap-xhdpi (96x96), mipmap-xxhdpi (144x144), mipmap-xxxhdpi (192x192)
- Adaptive icon foreground layers in the same densities
- Adaptive icon XML with `#FFFFFF` background

### Windows Output

- `app_icon.ico` in `windows/runner/resources/` (multi-resolution ICO)

### Additional Changes

- `AndroidManifest.xml`: change `android:label` from `"banana_split_flutter"` to `"Banana Split"`
- `about_screen.dart`: update `applicationIcon` in `showLicensePage()` to use the new icon asset (`Image.asset('assets/app_icon.png', width: 48, height: 48)`)
- `pubspec.yaml` assets: add `assets/app_icon.png`

---

## Testing

### Files Tab

- Unit test: file listing logic (mock directory with test files)
- Widget test: empty state renders, file list renders with mock data, delete confirmation dialog appears

### App Icon

- Manual verification only (visual). No automated tests needed.
