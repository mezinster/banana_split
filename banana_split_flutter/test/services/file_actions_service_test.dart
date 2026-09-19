import 'dart:io';
import 'dart:typed_data';

import 'package:banana_split_flutter/services/file_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';

void main() {
  group('mimeTypeFor', () {
    test('knows the two formats the app writes, whatever the case', () {
      expect(FileActionsService.mimeTypeFor('/a/shards.pdf'), 'application/pdf');
      expect(FileActionsService.mimeTypeFor('/a/SHARD_1.PNG'), 'image/png');
    });

    test('anything else is octet-stream, never a guess', () {
      expect(FileActionsService.mimeTypeFor('/a/notes'),
          'application/octet-stream');
    });
  });

  group('openFile', () {
    test('hands the opener the path and its MIME type', () async {
      String? seenPath;
      String? seenType;
      final service = FileActionsService(
        opener: (path, {type}) async {
          seenPath = path;
          seenType = type;
          return OpenResult(type: ResultType.done);
        },
      );

      expect(await service.openFile('/a/shards.pdf'), OpenOutcome.opened);
      expect(seenPath, '/a/shards.pdf');
      expect(seenType, 'application/pdf');
    });

    test('reports a missing viewer app separately from other failures',
        () async {
      for (final (result, outcome) in [
        (ResultType.noAppToOpen, OpenOutcome.noApp),
        (ResultType.fileNotFound, OpenOutcome.failed),
        (ResultType.permissionDenied, OpenOutcome.failed),
        (ResultType.error, OpenOutcome.failed),
      ]) {
        final service = FileActionsService(
          opener: (path, {type}) async => OpenResult(type: result),
        );
        expect(await service.openFile('/a/b.pdf'), outcome, reason: '$result');
      }
    });

    test('a throwing platform channel is a failure, not a crash', () async {
      final service = FileActionsService(
        opener: (path, {type}) async => throw Exception('channel down'),
      );
      expect(await service.openFile('/a/b.pdf'), OpenOutcome.failed);
    });
  });

  group('exportFile', () {
    late Directory tmp;
    late File source;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('bs-export-test');
      source = File('${tmp.path}/shard_1.png');
      await source.writeAsBytes([1, 2, 3]);
    });

    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('offers the picker the bare filename and the bytes', () async {
      String? seenName;
      Uint8List? seenBytes;
      final service = FileActionsService(
        pickerWritesBytes: true,
        saver: ({fileName, bytes}) async {
          seenName = fileName;
          seenBytes = bytes;
          return 'content://downloads/shard_1.png';
        },
      );

      expect(await service.exportFile(source.path), isTrue);
      expect(seenName, 'shard_1.png');
      expect(seenBytes, [1, 2, 3]);
    });

    test('a dismissed picker is not a save', () async {
      final service = FileActionsService(
        pickerWritesBytes: true,
        saver: ({fileName, bytes}) async => null,
      );
      expect(await service.exportFile(source.path), isFalse);
    });

    test('on desktop the picker only returns a path, so the file is written '
        'here', () async {
      // file_picker's desktop saveFile ignores `bytes`: without this the user
      // gets a success message and no file.
      final target = '${tmp.path}/chosen/copy.png';
      await Directory('${tmp.path}/chosen').create();
      final service = FileActionsService(
        pickerWritesBytes: false,
        saver: ({fileName, bytes}) async => target,
      );

      expect(await service.exportFile(source.path), isTrue);
      expect(await File(target).readAsBytes(), [1, 2, 3]);
    });

    test('where the picker writes the bytes itself, nothing is written twice',
        () async {
      // On Android the returned value is not a filesystem path we may write.
      final target = '${tmp.path}/must-not-exist.png';
      final service = FileActionsService(
        pickerWritesBytes: true,
        saver: ({fileName, bytes}) async => target,
      );

      expect(await service.exportFile(source.path), isTrue);
      expect(File(target).existsSync(), isFalse);
    });
  });
}
