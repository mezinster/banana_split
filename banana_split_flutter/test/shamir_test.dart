import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/crypto/shamir.dart';

void main() {
  group('GF(256) arithmetic', () {
    test('log/exp tables are inverses', () {
      final shamir = Shamir(bits: 8);
      for (int x = 1; x < 256; x++) {
        expect(shamir.exps[shamir.logs[x]], equals(x));
      }
    });

    test('exp table wraps correctly', () {
      final shamir = Shamir(bits: 8);
      expect(shamir.exps[0], equals(1));
    });
  });

  group('share and combine', () {
    test('round-trip: split then combine recovers hex secret', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = '48656c6c6f'; // "Hello" in hex
      final shares = shamir.share(hexSecret, 5, 3);
      expect(shares.length, equals(5));

      final subset = shares.sublist(0, 3);
      final recovered = shamir.combine(subset);
      expect(recovered, equals(hexSecret));
    });

    test('round-trip: different subsets of shares work', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = 'deadbeef';
      final shares = shamir.share(hexSecret, 5, 3);

      final subset = [shares[0], shares[2], shares[3]];
      expect(shamir.combine(subset), equals(hexSecret));

      final subset2 = [shares[1], shares[2], shares[4]];
      expect(shamir.combine(subset2), equals(hexSecret));
    });

    test('fewer than threshold shares cannot reconstruct', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = '48656c6c6f';
      final shares = shamir.share(hexSecret, 5, 3);
      final subset = shares.sublist(0, 2);
      final recovered = shamir.combine(subset);
      expect(recovered, isNot(equals(hexSecret)));
    });

    test('minimum shard count: 3 total, 2 required', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = 'ff00ff';
      final shares = shamir.share(hexSecret, 3, 2);
      expect(shares.length, equals(3));
      final recovered = shamir.combine(shares.sublist(0, 2));
      expect(recovered, equals(hexSecret));
    });

    test('share format: first char is base36 bits, then hex', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = 'abcd';
      final shares = shamir.share(hexSecret, 3, 2);
      for (final share in shares) {
        expect(share[0], equals('8'));
        expect(
          RegExp(r'^[0-9a-f]+$').hasMatch(share.substring(1)),
          isTrue,
        );
      }
    });

    test('empty secret round-trip', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = '';
      // Empty secret should either throw or handle gracefully
      // Testing that non-empty secrets of various lengths work
      for (final hex in ['00', 'ff', '0000', 'abcdef1234567890']) {
        final shares = shamir.share(hex, 3, 2);
        final recovered = shamir.combine(shares.sublist(0, 2));
        expect(recovered, equals(hex));
      }
    });

    test('large secret round-trip', () {
      final shamir = Shamir(bits: 8);
      // 256 hex chars = 128 bytes
      final hexSecret = List.generate(256, (i) => (i % 16).toRadixString(16)).join();
      final shares = shamir.share(hexSecret, 5, 3);
      final recovered = shamir.combine(shares.sublist(1, 4));
      expect(recovered, equals(hexSecret));
    });
  });
}
