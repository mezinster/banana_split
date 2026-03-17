import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/crypto/crypto.dart';
import 'package:banana_split_flutter/crypto/passphrase.dart';
import 'package:banana_split_flutter/models/shard.dart';

void main() {
  group('End-to-end integration', () {
    test('full create-then-restore flow', () async {
      final wordlist = List.generate(2048, (i) => 'word$i');
      final gen = PassphraseGenerator(wordlist);
      final passphrase = gen.generate(4);

      const secret = 'This is my very important seed phrase that must be kept safe';
      const title = 'Integration Test Wallet';

      final shardJsons = await BananaCrypto.share(
        data: secret, title: title, passphrase: passphrase,
        totalShards: 5, requiredShards: 3,
      );
      expect(shardJsons.length, equals(5));

      final shards = <Shard>[];
      for (final json in [shardJsons[0], shardJsons[2], shardJsons[4]]) {
        final shard = Shard.parse(json);
        expect(shard.version, equals(2));
        expect(shard.title, equals(title));
        shards.add(shard);
      }

      Shard.validateCompatibility(shards);
      final recovered = await BananaCrypto.reconstruct(shards, passphrase);
      expect(recovered, equals(secret));
    });

    test('passphrase normalization: spaces to hyphens', () async {
      const passphrase = 'alpha-bravo-charlie-delta';
      const passphraseWithSpaces = 'alpha bravo  charlie delta';

      final shardJsons = await BananaCrypto.share(
        data: 'test', title: 'normalize', passphrase: passphrase,
        totalShards: 3, requiredShards: 2,
      );

      final shards = shardJsons.sublist(0, 2).map(Shard.parse).toList();
      final normalized = passphraseWithSpaces
          .split(' ').where((s) => s.isNotEmpty).join('-');
      final recovered = await BananaCrypto.reconstruct(shards, normalized);
      expect(recovered, equals('test'));
    });

    test('unicode secret round-trip', () async {
      const secret = 'Hello World! CJK: \u4f60\u597d';
      final shardJsons = await BananaCrypto.share(
        data: secret, title: 'unicode', passphrase: 'test-pass',
        totalShards: 3, requiredShards: 2,
      );

      final shards = shardJsons.sublist(0, 2).map(Shard.parse).toList();
      final recovered = await BananaCrypto.reconstruct(shards, 'test-pass');
      expect(recovered, equals(secret));
    });

    test('maximum secret length (1024 chars)', () async {
      final secret = 'A' * 1024;
      final shardJsons = await BananaCrypto.share(
        data: secret, title: 'big', passphrase: 'pass',
        totalShards: 3, requiredShards: 2,
      );

      final shards = shardJsons.sublist(0, 2).map(Shard.parse).toList();
      final recovered = await BananaCrypto.reconstruct(shards, 'pass');
      expect(recovered, equals(secret));
    });

    test('shard validation catches mismatches', () async {
      final shardsA = await BananaCrypto.share(
        data: 'secretA', title: 'titleA', passphrase: 'pass',
        totalShards: 3, requiredShards: 2,
      );
      final shardsB = await BananaCrypto.share(
        data: 'secretB', title: 'titleB', passphrase: 'pass',
        totalShards: 3, requiredShards: 2,
      );

      final a = Shard.parse(shardsA[0]);
      final b = Shard.parse(shardsB[0]);
      expect(
        () => Shard.validateCompatibility([a, b]),
        throwsA(anything),
      );
    });
  });
}
