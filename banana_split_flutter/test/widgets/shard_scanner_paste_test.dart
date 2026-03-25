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

    testWidgets('submit button is disabled when input is empty or whitespace',
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

      // Submit text is visible
      expect(find.text('Submit'), findsOneWidget);

      // Tap Submit with empty field — should not trigger onScanned
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(calls.isEmpty, true);

      // Enter whitespace-only text and tap Submit — still should not trigger
      await tester.enterText(find.byType(TextField), '   \n  \n  ');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
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
