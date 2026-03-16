import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/crypto/crypto.dart';
import 'package:banana_split_flutter/models/shard.dart';

void main() {
  group('BananaCrypto', () {
    test('round-trip: share then reconstruct', () async {
      const secret = 'Hello, World!';
      const title = 'test-title';
      const passphrase = 'alpha-bravo-charlie-delta';

      final shardJsons = await BananaCrypto.share(
        data: secret, title: title, passphrase: passphrase,
        totalShards: 5, requiredShards: 3,
      );
      expect(shardJsons.length, equals(5));

      final shards = shardJsons.sublist(0, 3).map((s) => Shard.parse(s)).toList();
      final recovered = await BananaCrypto.reconstruct(shards, passphrase);
      expect(recovered, equals(secret));
    });

    test('round-trip: different subset of shards', () async {
      const secret = 'My secret seed phrase';
      const title = 'wallet';
      const passphrase = 'test-pass';

      final shardJsons = await BananaCrypto.share(
        data: secret, title: title, passphrase: passphrase,
        totalShards: 5, requiredShards: 3,
      );

      final shards = [shardJsons[1], shardJsons[3], shardJsons[4]]
          .map((s) => Shard.parse(s)).toList();
      final recovered = await BananaCrypto.reconstruct(shards, passphrase);
      expect(recovered, equals(secret));
    });

    test('wrong passphrase throws', () async {
      final shardJsons = await BananaCrypto.share(
        data: 'secret', title: 'test', passphrase: 'correct-pass',
        totalShards: 3, requiredShards: 2,
      );

      final shards = shardJsons.sublist(0, 2).map((s) => Shard.parse(s)).toList();
      expect(
        () async => await BananaCrypto.reconstruct(shards, 'wrong-pass'),
        throwsA(predicate((e) => e.toString().contains('Unable to decrypt'))),
      );
    });

    test('generated shards are v2 format', () async {
      final shardJsons = await BananaCrypto.share(
        data: 'test', title: 'title', passphrase: 'pass',
        totalShards: 3, requiredShards: 2,
      );

      for (final json in shardJsons) {
        final shard = Shard.parse(json);
        expect(shard.version, equals(2));
      }
    });

    test('minimum shard count: 3 total, 2 required', () async {
      final shardJsons = await BananaCrypto.share(
        data: 'min', title: 'min-test', passphrase: 'pass',
        totalShards: 3, requiredShards: 2,
      );
      expect(shardJsons.length, equals(3));
    });

    test('v1 shard encoding is same as v2', () async {
      const secret = 'compat-test';
      const passphrase = 'pass';

      final shardJsons = await BananaCrypto.share(
        data: secret, title: 'compat', passphrase: passphrase,
        totalShards: 3, requiredShards: 2,
      );

      final v2Shards = shardJsons.sublist(0, 2).map((s) => Shard.parse(s)).toList();
      expect(await BananaCrypto.reconstruct(v2Shards, passphrase), equals(secret));

      // Fake as v1 — should still work
      final v1Shards = v2Shards.map((s) => Shard(
        version: 1, title: s.title, requiredShards: s.requiredShards,
        data: s.data, nonce: s.nonce,
      )).toList();
      expect(await BananaCrypto.reconstruct(v1Shards, passphrase), equals(secret));
    });
  });
}
