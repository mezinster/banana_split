# Files Tab & App Icon Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Files tab for browsing/sharing/deleting saved shards, and replace the default Flutter icon with the Banana Split logo on both Android and Windows.

**Architecture:** A new `FilesScreen` StatefulWidget scans `getApplicationDocumentsDirectory()/banana_split/` recursively for PNG/PDF files and displays them in a flat list with share/delete actions. The app icon is generated from a padded source PNG using `flutter_launcher_icons`.

**Tech Stack:** Flutter, path_provider (existing), share_plus (existing), intl (existing), flutter_launcher_icons (one-time dev tool), ImageMagick (CLI)

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/screens/files_screen.dart` | Files tab UI — list, share, delete |
| Create | `test/screens/files_screen_test.dart` | Widget tests for FilesScreen |
| Create | `assets/app_icon.png` | Square padded logo (1536x1536) |
| Modify | `lib/main.dart` | Add 4th tab (Files) to navigation |
| Modify | `lib/l10n/app_en.arb` | English localization keys |
| Modify | `lib/l10n/app_ru.arb` | Russian translations |
| Modify | `lib/l10n/app_tr.arb` | Turkish translations |
| Modify | `lib/l10n/app_be.arb` | Belarusian translations |
| Modify | `lib/l10n/app_ka.arb` | Georgian translations |
| Modify | `lib/l10n/app_uk.arb` | Ukrainian translations |
| Modify | `lib/screens/about_screen.dart` | Use app icon asset in license page |
| Modify | `pubspec.yaml` | Add app_icon.png to assets |
| Modify | `android/app/src/main/AndroidManifest.xml` | Fix app label |
| Modify | `android/app/src/main/res/mipmap-*/` | Generated icon files |
| Modify | `windows/runner/resources/app_icon.ico` | Generated Windows icon |

---

## Chunk 1: Files Tab

### Task 1: Add localization keys for Files tab

**Files:**
- Modify: `banana_split_flutter/lib/l10n/app_en.arb`
- Modify: `banana_split_flutter/lib/l10n/app_ru.arb`
- Modify: `banana_split_flutter/lib/l10n/app_tr.arb`
- Modify: `banana_split_flutter/lib/l10n/app_be.arb`
- Modify: `banana_split_flutter/lib/l10n/app_ka.arb`
- Modify: `banana_split_flutter/lib/l10n/app_uk.arb`

- [ ] **Step 1: Add keys to app_en.arb**

In `banana_split_flutter/lib/l10n/app_en.arb`, add a comma after the `privacyPolicyBody` value (the last entry before `}`), then add these new entries before the closing `}`:

```json
  "tabFiles": "Files",
  "filesEmpty": "No saved files.\nCreate shards and save them to see files here.",
  "filesDeleteConfirmTitle": "Delete file?",
  "filesDeleteConfirmBody": "This will permanently delete {filename}.",
  "@filesDeleteConfirmBody": { "placeholders": { "filename": { "type": "String" } } },
  "filesDeleteButton": "Delete",
  "filesCancelButton": "Cancel",
  "filesDeleted": "File deleted",
  "filesShareError": "Error sharing file",
  "filesDeleteError": "Error deleting file"
```

- [ ] **Step 2: Add keys to app_ru.arb**

Add a comma after the last entry, then add before the closing `}`:

```json
  "tabFiles": "Файлы",
  "filesEmpty": "Нет сохранённых файлов.\nСоздайте осколки и сохраните их, чтобы увидеть файлы здесь.",
  "filesDeleteConfirmTitle": "Удалить файл?",
  "filesDeleteConfirmBody": "Файл {filename} будет удалён навсегда.",
  "@filesDeleteConfirmBody": { "placeholders": { "filename": { "type": "String" } } },
  "filesDeleteButton": "Удалить",
  "filesCancelButton": "Отмена",
  "filesDeleted": "Файл удалён",
  "filesShareError": "Ошибка при отправке файла",
  "filesDeleteError": "Ошибка при удалении файла"
```

- [ ] **Step 3: Add keys to app_tr.arb**

Add a comma after the last entry, then add before the closing `}`:

```json
  "tabFiles": "Dosyalar",
  "filesEmpty": "Kayıtlı dosya yok.\nParçalar oluşturup kaydedin.",
  "filesDeleteConfirmTitle": "Dosya silinsin mi?",
  "filesDeleteConfirmBody": "{filename} kalıcı olarak silinecek.",
  "@filesDeleteConfirmBody": { "placeholders": { "filename": { "type": "String" } } },
  "filesDeleteButton": "Sil",
  "filesCancelButton": "İptal",
  "filesDeleted": "Dosya silindi",
  "filesShareError": "Dosya paylaşılırken hata oluştu",
  "filesDeleteError": "Dosya silinirken hata oluştu"
```

- [ ] **Step 4: Add keys to app_be.arb**

Add a comma after the last entry, then add before the closing `}`:

```json
  "tabFiles": "Файлы",
  "filesEmpty": "Няма захаваных файлаў.\nСтварыце асколкі і захавайце іх.",
  "filesDeleteConfirmTitle": "Выдаліць файл?",
  "filesDeleteConfirmBody": "Файл {filename} будзе выдалены назаўсёды.",
  "@filesDeleteConfirmBody": { "placeholders": { "filename": { "type": "String" } } },
  "filesDeleteButton": "Выдаліць",
  "filesCancelButton": "Адмена",
  "filesDeleted": "Файл выдалены",
  "filesShareError": "Памылка пры адпраўцы файла",
  "filesDeleteError": "Памылка пры выдаленні файла"
```

- [ ] **Step 5: Add keys to app_ka.arb**

Add a comma after the last entry, then add before the closing `}`:

```json
  "tabFiles": "ფაილები",
  "filesEmpty": "შენახული ფაილები არ არის.\nშექმენით ფრაგმენტები და შეინახეთ.",
  "filesDeleteConfirmTitle": "წაიშალოს ფაილი?",
  "filesDeleteConfirmBody": "{filename} სამუდამოდ წაიშლება.",
  "@filesDeleteConfirmBody": { "placeholders": { "filename": { "type": "String" } } },
  "filesDeleteButton": "წაშლა",
  "filesCancelButton": "გაუქმება",
  "filesDeleted": "ფაილი წაიშალა",
  "filesShareError": "ფაილის გაზიარების შეცდომა",
  "filesDeleteError": "ფაილის წაშლის შეცდომა"
```

- [ ] **Step 6: Add keys to app_uk.arb**

Add a comma after the last entry, then add before the closing `}`:

```json
  "tabFiles": "Файли",
  "filesEmpty": "Немає збережених файлів.\nСтворіть осколки та збережіть їх.",
  "filesDeleteConfirmTitle": "Видалити файл?",
  "filesDeleteConfirmBody": "Файл {filename} буде видалено назавжди.",
  "@filesDeleteConfirmBody": { "placeholders": { "filename": { "type": "String" } } },
  "filesDeleteButton": "Видалити",
  "filesCancelButton": "Скасувати",
  "filesDeleted": "Файл видалено",
  "filesShareError": "Помилка при надсиланні файлу",
  "filesDeleteError": "Помилка при видаленні файлу"
```

- [ ] **Step 7: Run code generation and verify**

```bash
cd banana_split_flutter && flutter gen-l10n && flutter analyze
```

Expected: no issues.

- [ ] **Step 8: Commit**

```bash
git add lib/l10n/
git commit -m "l10n: add Files tab localization keys for all 6 languages"
```

---

### Task 2: Create FilesScreen

**Files:**
- Create: `banana_split_flutter/lib/screens/files_screen.dart`

- [ ] **Step 1: Create FilesScreen**

Create `banana_split_flutter/lib/screens/files_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bananaSplitDir = Directory('${dir.path}/banana_split');
      if (!await bananaSplitDir.exists()) {
        setState(() {
          _files = [];
          _loading = false;
        });
        return;
      }
      final entities = await bananaSplitDir
          .list(recursive: true)
          .where((e) =>
              e is File &&
              (e.path.endsWith('.png') || e.path.endsWith('.pdf')))
          .cast<File>()
          .toList();
      // Sort by last modified, newest first
      entities.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      setState(() {
        _files = entities;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _files = [];
        _loading = false;
      });
    }
  }

  String _humanFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _subtitle(File file) {
    final normalized = file.path.replaceAll('\\', '/');
    final bananaSplitIndex = normalized.indexOf('banana_split/');
    if (bananaSplitIndex == -1) return '';
    final relative = normalized.substring(bananaSplitIndex + 'banana_split/'.length);
    final parts = relative.split('/');
    if (parts.length > 1) return parts.first;
    return '';
  }

  Future<void> _shareFile(File file) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.filesShareError)),
      );
    }
  }

  Future<void> _deleteFile(File file) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filesDeleteConfirmTitle),
        content: Text(l10n.filesDeleteConfirmBody(file.uri.pathSegments.last)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.filesCancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.filesDeleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await file.delete();
      // Remove parent dir if empty
      final parent = file.parent;
      final remaining = await parent.list().toList();
      if (remaining.isEmpty) {
        await parent.delete();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.filesDeleted)),
      );
      await _loadFiles();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.filesDeleteError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.filesEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final stat = file.statSync();
          final subtitle = _subtitle(file);
          final dateStr = DateFormat.yMMMd().format(stat.modified);
          final sizeStr = _humanFileSize(stat.size);
          return ListTile(
            leading: Icon(
              file.path.endsWith('.pdf')
                  ? Icons.picture_as_pdf
                  : Icons.image_outlined,
            ),
            title: Text(file.uri.pathSegments.last),
            subtitle: Text(
              subtitle.isEmpty
                  ? '$sizeStr · $dateStr'
                  : '$subtitle · $sizeStr · $dateStr',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareFile(file),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteFile(file),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/files_screen.dart
git commit -m "feat: add FilesScreen with file listing, share, and delete"
```

---

### Task 3: Integrate Files tab into navigation

**Files:**
- Modify: `banana_split_flutter/lib/main.dart`

- [ ] **Step 1: Add import**

At the top of `banana_split_flutter/lib/main.dart`, after the existing screen imports, add:

```dart
import 'package:banana_split_flutter/screens/files_screen.dart';
```

- [ ] **Step 2: Add FilesScreen to the screens list**

Find the `_screens` list in `_HomeShellState` and replace it with:

```dart
  static const List<Widget> _screens = [
    CreateScreen(),
    RestoreScreen(),
    FilesScreen(),
    AboutScreen(),
  ];
```

- [ ] **Step 3: Add Files NavigationDestination**

In the `destinations` list inside `build()`, add a new `NavigationDestination` between Restore and About (after the Restore destination, before the About destination):

```dart
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: l10n.tabFiles,
          ),
```

- [ ] **Step 4: Run all tests and analyze**

```bash
cd banana_split_flutter && flutter test && flutter analyze
```

Expected: all tests pass, no analysis issues.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add Files tab to bottom navigation (4th tab)"
```

---

### Task 4: Add widget tests for FilesScreen

**Files:**
- Create: `banana_split_flutter/test/screens/files_screen_test.dart`

- [ ] **Step 1: Write widget tests**

Create `banana_split_flutter/test/screens/files_screen_test.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:banana_split_flutter/screens/files_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String documentsPath;
  FakePathProvider(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

Widget buildTestApp() {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: FilesScreen()),
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('files_test_');
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('shows empty state when no banana_split dir exists', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved files'), findsOneWidget);
  });

  testWidgets('shows empty state when banana_split dir is empty', (tester) async {
    Directory('${tempDir.path}/banana_split').createSync();
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved files'), findsOneWidget);
  });

  testWidgets('lists PDF and PNG files', (tester) async {
    final subDir = Directory('${tempDir.path}/banana_split/My_Secret');
    subDir.createSync(recursive: true);
    File('${subDir.path}/shard_1.png').writeAsBytesSync([0]);
    File('${tempDir.path}/banana_split/My_Secret_shards.pdf').writeAsBytesSync([0]);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.text('shard_1.png'), findsOneWidget);
    expect(find.text('My_Secret_shards.pdf'), findsOneWidget);
  });

  testWidgets('shows subtitle for files in subdirectory', (tester) async {
    final subDir = Directory('${tempDir.path}/banana_split/My_Secret');
    subDir.createSync(recursive: true);
    File('${subDir.path}/shard_1.png').writeAsBytesSync([0]);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('My_Secret'), findsOneWidget);
  });

  testWidgets('delete button shows confirmation dialog', (tester) async {
    final dir = Directory('${tempDir.path}/banana_split');
    dir.createSync(recursive: true);
    File('${dir.path}/test.pdf').writeAsBytesSync([0]);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    // Tap the delete icon
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // Confirmation dialog should appear
    expect(find.text('Delete file?'), findsOneWidget);
    expect(find.textContaining('test.pdf'), findsWidgets);
  });

  testWidgets('confirming delete removes file from list', (tester) async {
    final dir = Directory('${tempDir.path}/banana_split');
    dir.createSync(recursive: true);
    File('${dir.path}/test.pdf').writeAsBytesSync([0]);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // Tap "Delete" button in dialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // File should be gone
    expect(find.text('test.pdf'), findsNothing);
    expect(find.textContaining('No saved files'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests**

```bash
cd banana_split_flutter && flutter test test/screens/files_screen_test.dart
```

Expected: 6 tests pass.

- [ ] **Step 3: Commit**

```bash
cd banana_split_flutter && git add test/screens/files_screen_test.dart
git commit -m "test: add widget tests for FilesScreen (empty state, listing, delete)"
```

---

## Chunk 2: App Icon

### Task 5: Prepare and generate app icon

**Files:**
- Create: `banana_split_flutter/assets/app_icon.png`
- Modify: `banana_split_flutter/pubspec.yaml`
- Modify: `banana_split_flutter/android/app/src/main/res/mipmap-*/`
- Modify: `banana_split_flutter/windows/runner/resources/app_icon.ico`

- [ ] **Step 1: Pad the source image to square**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && convert /mnt/c/Users/Evgeny_Mezin/Downloads/Banana_Split.png -gravity center -background transparent -extent 1536x1536 assets/app_icon.png
```

Verify: `file assets/app_icon.png` should show `PNG image data, 1536 x 1536`.

- [ ] **Step 2: Add app_icon.png to pubspec.yaml assets**

In `banana_split_flutter/pubspec.yaml`, find the `assets:` section and add the icon:

```yaml
  assets:
    - assets/wordlist.txt
    - assets/app_icon.png
```

- [ ] **Step 3: Add flutter_launcher_icons dev dependency and config**

In `banana_split_flutter/pubspec.yaml`, add to `dev_dependencies:`:

```yaml
  flutter_launcher_icons: ^0.14.3
```

Add at the root level of the YAML (after the `flutter:` section):

```yaml
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

- [ ] **Step 4: Run pub get and generate icons**

```bash
cd banana_split_flutter && flutter pub get && dart run flutter_launcher_icons
```

Expected: generates icons for Android (mipmap-mdpi through mipmap-xxxhdpi) and Windows (app_icon.ico).

- [ ] **Step 5: Remove flutter_launcher_icons from pubspec.yaml**

Remove `flutter_launcher_icons: ^0.14.3` from `dev_dependencies` and remove the entire `flutter_launcher_icons:` config block from the root of pubspec.yaml. Then run:

```bash
cd banana_split_flutter && flutter pub get
```

- [ ] **Step 6: Fix Android app label**

In `banana_split_flutter/android/app/src/main/AndroidManifest.xml`, change:

```xml
android:label="banana_split_flutter"
```

to:

```xml
android:label="Banana Split"
```

- [ ] **Step 7: Commit all generated icons and config changes**

```bash
git add assets/app_icon.png pubspec.yaml pubspec.lock android/ windows/runner/resources/
git commit -m "feat: replace default icon with Banana Split logo (Android + Windows)"
```

---

### Task 6: Update about screen icon

**Files:**
- Modify: `banana_split_flutter/lib/screens/about_screen.dart`

- [ ] **Step 1: Update applicationIcon in showLicensePage**

In `banana_split_flutter/lib/screens/about_screen.dart`, find the `showLicensePage` call (around line 65) and replace the `applicationIcon` parameter:

```dart
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/app_icon.png', width: 48, height: 48),
                ),
```

Note: remove `const` from the `Padding` since `Image.asset` is not const.

- [ ] **Step 2: Run flutter analyze**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: no issues.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/about_screen.dart
git commit -m "feat: use Banana Split logo in license page"
```

---

### Task 7: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Run all tests**

```bash
cd banana_split_flutter && flutter test
```

Expected: all tests pass.

- [ ] **Step 2: Run flutter analyze**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: no issues found.

- [ ] **Step 3: Manual smoke test (if device available)**

```bash
cd banana_split_flutter && flutter run
```

Verify:
- 4 tabs visible: Create, Restore, Files, About.
- Files tab shows empty state when no files saved.
- Create some shards, save as PDF/PNG.
- Files tab shows the saved files with correct names, sizes, dates.
- Share button opens system share sheet.
- Delete button shows confirmation dialog; confirming deletes the file.
- App icon is the Banana Split logo (check launcher, recent apps).
- License page shows the Banana Split logo.
- App label shows "Banana Split" (not "banana_split_flutter").
