import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/models/shard.dart';

void main() {
  group('Shard.parse', () {
    test('parses v1 shard JSON', () {
      const json = '{"v":1,"t":"test","r":3,"d":"7abc123","n":"bm9uY2U="}';
      final shard = Shard.parse(json);
      expect(shard.version, equals(1));
      expect(shard.title, equals('test'));
      expect(shard.requiredShards, equals(3));
      expect(shard.data, equals('7abc123'));
      expect(shard.nonce, equals('bm9uY2U='));
    });

    test('parses v0 shard (missing version field)', () {
      const json = '{"t":"old","r":2,"d":"deadbeef","n":"aabbcc"}';
      final shard = Shard.parse(json);
      expect(shard.version, equals(0));
    });

    test('parses v2 shard JSON', () {
      const json = '{"v":2,"t":"flutter","r":3,"d":"7xyz","n":"bm9uY2U="}';
      final shard = Shard.parse(json);
      expect(shard.version, equals(2));
    });

    test('throws on invalid JSON', () {
      expect(() => Shard.parse('not json'), throwsFormatException);
    });
  });

  group('Shard.toJson', () {
    test('serializes as v2', () {
      const shard = Shard(
        version: 2, title: 'test', requiredShards: 3,
        data: '7abc', nonce: 'bm9uY2U=',
      );
      final json = shard.toJson();
      expect(json, contains('"v":2'));
      expect(json, contains('"t":"test"'));
      expect(json, contains('"r":3'));
    });
  });

  group('Shard validation', () {
    test('validateCompatibility passes for matching shards', () {
      const a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n');
      const b = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd2', nonce: 'n');
      Shard.validateCompatibility([a, b]);
    });

    test('validateCompatibility throws on title mismatch', () {
      const a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n');
      const b = Shard(version: 1, title: 'y', requiredShards: 3, data: 'd2', nonce: 'n');
      expect(() => Shard.validateCompatibility([a, b]),
        throwsA(predicate((e) => e.toString().contains('itle'))));
    });

    test('validateCompatibility throws on version mismatch', () {
      const a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n');
      const b = Shard(version: 2, title: 'x', requiredShards: 3, data: 'd2', nonce: 'n');
      expect(() => Shard.validateCompatibility([a, b]),
        throwsA(predicate((e) => e.toString().contains('ersion'))));
    });

    test('validateCompatibility throws on nonce mismatch', () {
      const a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n1');
      const b = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd2', nonce: 'n2');
      expect(() => Shard.validateCompatibility([a, b]),
        throwsA(predicate((e) => e.toString().contains('once'))));
    });

    test('validateCompatibility throws on requiredShards mismatch', () {
      const a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n');
      const b = Shard(version: 1, title: 'x', requiredShards: 4, data: 'd2', nonce: 'n');
      expect(() => Shard.validateCompatibility([a, b]),
        throwsA(predicate((e) => e.toString().contains('shard'))));
    });
  });
}
