import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/state/restore_notifier.dart';

void main() {
  late RestoreNotifier notifier;

  setUp(() {
    notifier = RestoreNotifier();
  });

  group('addShard', () {
    test('returns EmptyQrError for empty input', () {
      expect(notifier.addShard(''), isA<EmptyQrError>());
      expect(notifier.addShard('  '), isA<EmptyQrError>());
    });

    test('returns ParseError for invalid JSON', () {
      expect(notifier.addShard('not json'), isA<ParseError>());
    });

    test('returns null for valid shard', () {
      const validShard = '{"v":2,"t":"test","r":3,"d":"abc","n":"xyz"}';
      expect(notifier.addShard(validShard), isNull);
      expect(notifier.scannedCount, 1);
    });

    test('returns DuplicateShardError for same shard twice', () {
      const validShard = '{"v":2,"t":"test","r":3,"d":"abc","n":"xyz"}';
      notifier.addShard(validShard);
      expect(notifier.addShard(validShard), isA<DuplicateShardError>());
    });

    test('returns TitleMismatchError for different titles', () {
      const shard1 = '{"v":2,"t":"test1","r":3,"d":"abc","n":"xyz"}';
      const shard2 = '{"v":2,"t":"test2","r":3,"d":"def","n":"xyz"}';
      notifier.addShard(shard1);
      final error = notifier.addShard(shard2);
      expect(error, isA<TitleMismatchError>());
      expect((error as TitleMismatchError).expected, 'test1');
      expect(error.actual, 'test2');
    });
  });
}
