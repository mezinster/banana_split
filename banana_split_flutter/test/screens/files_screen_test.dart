import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:banana_split_flutter/l10n/app_localizations.dart';
import 'package:banana_split_flutter/screens/files_screen.dart';
import 'package:banana_split_flutter/services/file_actions_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String documentsPath;
  FakePathProvider(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() =>
      Future<String?>.value(documentsPath);
}

Widget buildTestApp({Key? key, FileActionsService? actions}) {
  return MaterialApp(
    key: key,
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: FilesScreen(actions: actions)),
  );
}

/// Builds and loads the FilesScreen, waiting for async file I/O to complete.
/// Runs [tester.pumpWidget] inside [tester.runAsync] so that directory listing
/// uses the real I/O scheduler rather than the fake-async zone.
Future<void> pumpFilesScreen(
  WidgetTester tester, {
  Key? key,
  FileActionsService? actions,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
        buildTestApp(key: key ?? UniqueKey(), actions: actions));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

/// Delete, Share, Open and Save to device live in the row's overflow menu.
Future<void> openRowMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
}

class RecordingActions extends FileActionsService {
  RecordingActions({this.open = OpenOutcome.opened, this.saved = true});

  final OpenOutcome open;
  final bool saved;
  final opened = <String>[];
  final exported = <String>[];
  final shared = <String>[];

  @override
  Future<OpenOutcome> openFile(String filePath) async {
    opened.add(filePath);
    return open;
  }

  @override
  Future<bool> exportFile(String filePath) async {
    exported.add(filePath);
    return saved;
  }

  @override
  Future<void> shareFile(String filePath) async => shared.add(filePath);
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

  testWidgets('shows empty state when no banana_split dir exists',
      (tester) async {
    await pumpFilesScreen(tester);
    expect(find.textContaining('No saved files'), findsOneWidget);
  });

  testWidgets('shows empty state when banana_split dir is empty',
      (tester) async {
    Directory('${tempDir.path}/banana_split').createSync();
    await pumpFilesScreen(tester);
    expect(find.textContaining('No saved files'), findsOneWidget);
  });

  testWidgets('lists PDF and PNG files', (tester) async {
    final subDir = Directory('${tempDir.path}/banana_split/My_Secret');
    subDir.createSync(recursive: true);
    File('${subDir.path}/shard_1.png').writeAsBytesSync([0]);
    File('${tempDir.path}/banana_split/My_Secret_shards.pdf')
        .writeAsBytesSync([0]);
    await pumpFilesScreen(tester);
    expect(find.text('shard_1.png'), findsOneWidget);
    expect(find.text('My_Secret_shards.pdf'), findsOneWidget);
  });

  testWidgets('shows subtitle for files in subdirectory', (tester) async {
    final subDir = Directory('${tempDir.path}/banana_split/My_Secret');
    subDir.createSync(recursive: true);
    File('${subDir.path}/shard_1.png').writeAsBytesSync([0]);
    await pumpFilesScreen(tester);
    expect(find.textContaining('My_Secret'), findsOneWidget);
  });

  testWidgets('delete button shows confirmation dialog', (tester) async {
    final dir = Directory('${tempDir.path}/banana_split');
    dir.createSync(recursive: true);
    File('${dir.path}/test.pdf').writeAsBytesSync([0]);
    await pumpFilesScreen(tester);
    await openRowMenu(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsOneWidget);
    expect(find.textContaining('test.pdf'), findsWidgets);
  });

  testWidgets('confirming delete removes file from list', (tester) async {
    final dir = Directory('${tempDir.path}/banana_split');
    dir.createSync(recursive: true);
    File('${dir.path}/test.pdf').writeAsBytesSync([0]);

    await pumpFilesScreen(tester);
    expect(find.text('test.pdf'), findsOneWidget);

    // Open confirmation dialog.
    await openRowMenu(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete file?'), findsOneWidget);

    // Confirm deletion. pumpAndSettle drives the file.delete() I/O to
    // completion since it runs in the current fake-async zone.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Rebuild the screen from scratch (new key forces a fresh initState +
    // _loadFiles) so the updated directory listing is visible.
    await pumpFilesScreen(tester);

    expect(find.text('test.pdf'), findsNothing);
    expect(find.textContaining('No saved files'), findsOneWidget);
  });

  group('open / save / share', () {
    late String pdf;

    setUp(() {
      final dir = Directory('${tempDir.path}/banana_split');
      dir.createSync(recursive: true);
      pdf = '${dir.path}/shards.pdf';
      File(pdf).writeAsBytesSync([0]);
    });

    testWidgets('tapping a file opens it', (tester) async {
      final actions = RecordingActions();
      await pumpFilesScreen(tester, actions: actions);

      await tester.tap(find.text('shards.pdf'));
      await tester.pumpAndSettle();

      expect(actions.opened, [pdf]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('says so when no installed app can open the file',
        (tester) async {
      await pumpFilesScreen(tester,
          actions: RecordingActions(open: OpenOutcome.noApp));

      await tester.tap(find.text('shards.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('No app installed to open this file'), findsOneWidget);
    });

    testWidgets('reports a failed open', (tester) async {
      await pumpFilesScreen(tester,
          actions: RecordingActions(open: OpenOutcome.failed));

      await tester.tap(find.text('shards.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open the file'), findsOneWidget);
    });

    testWidgets('the row menu offers open, save, share and delete',
        (tester) async {
      await pumpFilesScreen(tester, actions: RecordingActions());
      await openRowMenu(tester);

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Save to device'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Save to device exports the file and confirms it',
        (tester) async {
      final actions = RecordingActions();
      await pumpFilesScreen(tester, actions: actions);
      await openRowMenu(tester);

      await tester.tap(find.text('Save to device'));
      await tester.pumpAndSettle();

      expect(actions.exported, [pdf]);
      expect(find.text('Saved to device'), findsOneWidget);
    });

    testWidgets('a dismissed save picker confirms nothing', (tester) async {
      final actions = RecordingActions(saved: false);
      await pumpFilesScreen(tester, actions: actions);
      await openRowMenu(tester);

      await tester.tap(find.text('Save to device'));
      await tester.pumpAndSettle();

      expect(actions.exported, [pdf]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Share goes through the service, which types the file',
        (tester) async {
      final actions = RecordingActions();
      await pumpFilesScreen(tester, actions: actions);
      await openRowMenu(tester);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(actions.shared, [pdf]);
    });
  });
}
