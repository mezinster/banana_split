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
  Future<String?> getApplicationDocumentsPath() =>
      Future<String?>.value(documentsPath);
}

Widget buildTestApp({Key? key}) {
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
    home: const Scaffold(body: FilesScreen()),
  );
}

/// Builds and loads the FilesScreen, waiting for async file I/O to complete.
/// Runs [tester.pumpWidget] inside [tester.runAsync] so that directory listing
/// uses the real I/O scheduler rather than the fake-async zone.
Future<void> pumpFilesScreen(WidgetTester tester, {Key? key}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(buildTestApp(key: key ?? UniqueKey()));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
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
}
