# Banana Split Flutter App — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter app that splits secrets into QR code shards using Shamir's Secret Sharing, compatible with the existing Banana Split web app's shard format.

**Architecture:** Pure Dart crypto (pinenacl for NaCl, pointycastle for scrypt, custom Shamir port). Provider-based state management. Three-tab layout: Create, Restore, About.

**Tech Stack:** Flutter 3.x, Dart, pinenacl, pointycastle, qr_flutter, mobile_scanner, share_plus, pdf, provider

**Spec:** `docs/superpowers/specs/2026-03-17-flutter-app-design.md`

---

## Chunk 1: Project Scaffold + Shamir Core

### Task 1: Create Flutter project and add dependencies

**Files:**
- Create: `banana_split_flutter/pubspec.yaml`
- Create: `banana_split_flutter/lib/main.dart` (minimal)
- Create: `banana_split_flutter/analysis_options.yaml`

- [ ] **Step 1: Create Flutter project**

```bash
cd /home/mezinster/banana_split
flutter create banana_split_flutter --platforms=android,linux,macos,windows
```

- [ ] **Step 2: Replace pubspec.yaml dependencies**

Replace the `dependencies` and `dev_dependencies` sections in `banana_split_flutter/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  pinenacl: ^0.6.0
  pointycastle: ^3.9.1
  qr_flutter: ^4.1.0
  mobile_scanner: ^5.1.1
  image_picker: ^1.1.2
  share_plus: ^9.0.0
  pdf: ^3.11.1
  provider: ^6.1.2
  path_provider: ^2.1.4
  permission_handler: ^11.3.1
  zxing2: ^0.2.3
  image: ^4.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

Add assets section under `flutter:`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/wordlist.txt
```

- [ ] **Step 3: Run flutter pub get**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter pub get
```

Expected: Dependencies resolve successfully.

- [ ] **Step 4: Verify project builds**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter analyze
```

Expected: No analysis issues.

- [ ] **Step 5: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/
git commit -m "feat: scaffold Flutter project with dependencies"
```

---

### Task 2: Port Shamir's Secret Sharing — GF(256) arithmetic

This is the most critical task. Port the GF(256) finite-field math from `secrets.js-grempe`.

**Files:**
- Create: `banana_split_flutter/lib/crypto/shamir.dart`
- Create: `banana_split_flutter/test/shamir_test.dart`

- [ ] **Step 1: Write failing tests for GF(256) primitives**

```dart
// banana_split_flutter/test/shamir_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/crypto/shamir.dart';

void main() {
  group('GF(256) arithmetic', () {
    test('log/exp tables are inverses', () {
      final shamir = Shamir(bits: 8);
      // For every non-zero element x in GF(256), exp(log(x)) == x
      for (int x = 1; x < 256; x++) {
        expect(shamir.exps[shamir.logs[x]], equals(x));
      }
    });

    test('exp table wraps correctly', () {
      final shamir = Shamir(bits: 8);
      // exp[0] should be 1 (generator^0 = 1)
      expect(shamir.exps[0], equals(1));
    });
  });

  group('share and combine', () {
    test('round-trip: split then combine recovers hex secret', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = '48656c6c6f'; // "Hello" in hex
      final shares = shamir.share(hexSecret, 5, 3);
      expect(shares.length, equals(5));

      // Any 3 shares should reconstruct
      final subset = shares.sublist(0, 3);
      final recovered = shamir.combine(subset);
      expect(recovered, equals(hexSecret));
    });

    test('round-trip: different subsets of shares work', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = 'deadbeef';
      final shares = shamir.share(hexSecret, 5, 3);

      // Try shares [1, 3, 4]
      final subset = [shares[0], shares[2], shares[3]];
      expect(shamir.combine(subset), equals(hexSecret));

      // Try shares [2, 3, 5]
      final subset2 = [shares[1], shares[2], shares[4]];
      expect(shamir.combine(subset2), equals(hexSecret));
    });

    test('fewer than threshold shares cannot reconstruct', () {
      final shamir = Shamir(bits: 8);
      const hexSecret = '48656c6c6f';
      final shares = shamir.share(hexSecret, 5, 3);
      final subset = shares.sublist(0, 2);
      // Combine with too few shares — result should NOT match
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
        // First char should be '8' (bits=8 in base36)
        expect(share[0], equals('8'));
        // Rest should be valid hex
        expect(
          RegExp(r'^[0-9a-f]+$').hasMatch(share.substring(1)),
          isTrue,
        );
      }
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test test/shamir_test.dart
```

Expected: FAIL — `shamir.dart` doesn't exist yet.

- [ ] **Step 3: Implement Shamir class**

```dart
// banana_split_flutter/lib/crypto/shamir.dart
import 'dart:math';
import 'dart:typed_data';

/// Primitive polynomials for GF(2^n), indexed by n (3..20).
/// Same values as secrets.js-grempe.
const List<int> _primitivePolynomials = [
  0,    // 0 (unused)
  0,    // 1 (unused)
  0,    // 2 (unused)
  3,    // 3: x^3 + x + 1
  3,    // 4: x^4 + x + 1
  5,    // 5: x^5 + x^2 + 1
  3,    // 6: x^6 + x + 1
  3,    // 7: x^7 + x + 1
  29,   // 8: x^8 + x^4 + x^3 + x^2 + 1
  17,   // 9
  9,    // 10
  5,    // 11
  83,   // 12
  27,   // 13
  43,   // 14
  3,    // 15
  45,   // 16
  9,    // 17
  39,   // 18
  39,   // 19
  9,    // 20
];

class Shamir {
  final int bits;
  late final int _size;       // 2^bits
  late final int _maxShares;  // size - 1
  late final List<int> logs;
  late final List<int> exps;
  late final Random _rng;

  Shamir({this.bits = 8}) {
    if (bits < 3 || bits > 20) {
      throw ArgumentError('bits must be between 3 and 20');
    }
    _size = 1 << bits;
    _maxShares = _size - 1;
    _rng = Random.secure();
    _initTables();
  }

  /// Build log/exp lookup tables for GF(2^bits).
  void _initTables() {
    final primitive = _primitivePolynomials[bits];
    logs = List<int>.filled(_size, 0);
    exps = List<int>.filled(_size, 0);

    int x = 1;
    for (int i = 0; i < _size; i++) {
      exps[i] = x;
      logs[x] = i;
      x = x << 1;
      if (x >= _size) {
        x = (x ^ primitive) & _maxShares;
      }
    }
  }

  /// Evaluate polynomial with coefficients [coeffs] at point [x]
  /// using Horner's method in GF(2^bits).
  int _horner(int x, List<int> coeffs) {
    final logx = logs[x];
    int fx = 0;
    for (int i = coeffs.length - 1; i >= 0; i--) {
      if (fx != 0) {
        fx = exps[(logx + logs[fx]) % _maxShares] ^ coeffs[i];
      } else {
        fx = coeffs[i];
      }
    }
    return fx;
  }

  /// Lagrange interpolation at point [at] given points (x[i], y[i])
  /// in GF(2^bits).
  int _lagrange(int at, List<int> x, List<int> y) {
    int sum = 0;
    final len = x.length;
    for (int i = 0; i < len; i++) {
      if (y[i] != 0) {
        int product = logs[y[i]];
        bool zeroProduct = false;
        for (int j = 0; j < len; j++) {
          if (i != j) {
            if (at == x[j]) {
              zeroProduct = true;
              break;
            }
            product = (product + logs[at ^ x[j]] - logs[x[i] ^ x[j]] + _maxShares) % _maxShares;
          }
        }
        if (!zeroProduct) {
          sum = sum ^ exps[product];
        }
      }
    }
    return sum;
  }

  /// Generate random coefficients for the polynomial.
  List<int> _randomCoeffs(int threshold) {
    final coeffs = <int>[];
    for (int i = 0; i < threshold - 1; i++) {
      coeffs.add(_rng.nextInt(_maxShares) + 1); // 1..maxShares
    }
    return coeffs;
  }

  /// Convert hex string to binary string.
  String _hex2bin(String hex) {
    final sb = StringBuffer();
    for (int i = 0; i < hex.length; i++) {
      final n = int.parse(hex[i], radix: 16);
      sb.write(n.toRadixString(2).padLeft(4, '0'));
    }
    return sb.toString();
  }

  /// Convert binary string to hex string.
  String _bin2hex(String bin) {
    // Pad to multiple of 4
    final padded = bin.padLeft(((bin.length + 3) ~/ 4) * 4, '0');
    final sb = StringBuffer();
    for (int i = 0; i < padded.length; i += 4) {
      sb.write(int.parse(padded.substring(i, i + 4), radix: 2).toRadixString(16));
    }
    return sb.toString();
  }

  /// Split a binary number string into an array of integers, each [bits] wide.
  /// Pads to multiple of [padLength] first.
  List<int> _splitNumStringToIntArray(String str, [int padLength = 128]) {
    // Pad to multiple of padLength
    if (padLength > 0) {
      final remainder = str.length % padLength;
      if (remainder > 0) {
        str = str.padLeft(str.length + (padLength - remainder), '0');
      }
    }

    final result = <int>[];
    for (int i = 0; i < str.length; i += bits) {
      final end = i + bits > str.length ? str.length : i + bits;
      result.add(int.parse(str.substring(i, end), radix: 2));
    }
    return result;
  }

  /// Left-pad a binary string to [bits] width.
  String _padLeft(String bin) {
    return bin.padLeft(bits, '0');
  }

  /// Split [hexSecret] into [numShares] shares requiring [threshold] to reconstruct.
  /// Returns a list of share strings in the same format as secrets.js-grempe.
  List<String> share(String hexSecret, int numShares, int threshold) {
    if (numShares < 2) throw ArgumentError('numShares must be >= 2');
    if (threshold < 2) throw ArgumentError('threshold must be >= 2');
    if (threshold > numShares) {
      throw ArgumentError('threshold must be <= numShares');
    }
    if (numShares > _maxShares) {
      throw ArgumentError('numShares exceeds max for $bits-bit field');
    }

    // Prepend "1" marker bit to preserve leading zeros
    final binSecret = '1${_hex2bin(hexSecret)}';
    final segments = _splitNumStringToIntArray(binSecret, 128);

    // For each share, collect y-values from all segments
    final x = List<String>.filled(numShares, '');
    final y = List<String>.filled(numShares, '');

    for (int i = 0; i < segments.length; i++) {
      // Create polynomial: coeffs[0] = secret segment, rest random
      final coeffs = <int>[segments[i], ..._randomCoeffs(threshold)];

      // Evaluate polynomial at x = 1, 2, ..., numShares
      for (int j = 0; j < numShares; j++) {
        final shareX = j + 1;
        final shareY = _horner(shareX, coeffs);

        if (i == 0) {
          x[j] = shareX.toRadixString(16);
        }
        y[j] = _padLeft(shareY.toRadixString(2)) + y[j];
      }
    }

    // Format shares: [bits in base36][hex id padded][hex data]
    final idMaxHexLen = _maxShares.toRadixString(16).length;
    final result = <String>[];
    for (int j = 0; j < numShares; j++) {
      final id = x[j].padLeft(idMaxHexLen, '0');
      final data = _bin2hex(y[j]);
      result.add('${bits.toRadixString(36)}$id$data');
    }
    return result;
  }

  /// Extract components from a share string.
  /// Returns (bits, id, data) where data is a hex string.
  ({int bits, int id, String data}) extractShareComponents(String share) {
    final shareBits = int.parse(share[0], radix: 36);
    if (shareBits < 3 || shareBits > 20) {
      throw FormatException('Invalid share: bits=$shareBits');
    }
    final maxSharesForBits = (1 << shareBits) - 1;
    final idHexLen = maxSharesForBits.toRadixString(16).length;
    final id = int.parse(share.substring(1, 1 + idHexLen), radix: 16);
    final data = share.substring(1 + idHexLen);
    return (bits: shareBits, id: id, data: data);
  }

  /// Combine [shares] to reconstruct the original hex secret.
  String combine(List<String> shares, {int at = 0}) {
    final xCoords = <int>[];
    final ySegments = <List<int>>[];

    for (final share in shares) {
      final components = extractShareComponents(share);

      // Skip duplicates
      if (xCoords.contains(components.id)) continue;

      xCoords.add(components.id);
      final binData = _hex2bin(components.data);
      final segments = _splitNumStringToIntArray(binData, 0);

      for (int j = 0; j < segments.length; j++) {
        if (j >= ySegments.length) {
          ySegments.add(<int>[]);
        }
        ySegments[j].add(segments[j]);
      }
    }

    // Lagrange interpolate each segment at x=0
    final sb = StringBuffer();
    for (int i = 0; i < ySegments.length; i++) {
      final val = _lagrange(at, xCoords, ySegments[i]);
      sb.write(_padLeft(val.toRadixString(2)));
    }

    String result = sb.toString();

    // Remove marker bit: find first "1" and strip it plus leading zeros
    if (at < 1) {
      final markerIdx = result.indexOf('1');
      if (markerIdx >= 0) {
        result = result.substring(markerIdx + 1);
      }
    }

    return _bin2hex(result);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test test/shamir_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/crypto/shamir.dart banana_split_flutter/test/shamir_test.dart
git commit -m "feat: implement Shamir's Secret Sharing over GF(256)"
```

---

### Task 3: Shard model with v0/v1/v2 parsing

**Files:**
- Create: `banana_split_flutter/lib/models/shard.dart`
- Create: `banana_split_flutter/test/shard_test.dart`

- [ ] **Step 1: Write failing tests for Shard parsing**

```dart
// banana_split_flutter/test/shard_test.dart
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
      final shard = Shard(
        version: 2,
        title: 'test',
        requiredShards: 3,
        data: '7abc',
        nonce: 'bm9uY2U=',
      );
      final json = shard.toJson();
      expect(json, contains('"v":2'));
      expect(json, contains('"t":"test"'));
      expect(json, contains('"r":3'));
    });
  });

  group('Shard validation', () {
    test('validateCompatibility passes for matching shards', () {
      final a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n');
      final b = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd2', nonce: 'n');
      // Should not throw
      Shard.validateCompatibility([a, b]);
    });

    test('validateCompatibility throws on title mismatch', () {
      final a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n');
      final b = Shard(version: 1, title: 'y', requiredShards: 3, data: 'd2', nonce: 'n');
      expect(
        () => Shard.validateCompatibility([a, b]),
        throwsA(predicate((e) => e.toString().contains('title'))),
      );
    });

    test('validateCompatibility throws on version mismatch', () {
      final a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n');
      final b = Shard(version: 2, title: 'x', requiredShards: 3, data: 'd2', nonce: 'n');
      expect(
        () => Shard.validateCompatibility([a, b]),
        throwsA(predicate((e) => e.toString().contains('version'))),
      );
    });

    test('validateCompatibility throws on nonce mismatch', () {
      final a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n1');
      final b = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd2', nonce: 'n2');
      expect(
        () => Shard.validateCompatibility([a, b]),
        throwsA(predicate((e) => e.toString().contains('nonce') || e.toString().contains('Nonce'))),
      );
    });

    test('validateCompatibility throws on requiredShards mismatch', () {
      final a = Shard(version: 1, title: 'x', requiredShards: 3, data: 'd1', nonce: 'n');
      final b = Shard(version: 1, title: 'x', requiredShards: 4, data: 'd2', nonce: 'n');
      expect(
        () => Shard.validateCompatibility([a, b]),
        throwsA(predicate((e) => e.toString().contains('requirement'))),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test test/shard_test.dart
```

Expected: FAIL — `shard.dart` doesn't exist yet.

- [ ] **Step 3: Implement Shard model**

```dart
// banana_split_flutter/lib/models/shard.dart
import 'dart:convert';

class Shard {
  final int version;
  final String title;
  final int requiredShards;
  final String data;
  final String nonce;

  const Shard({
    required this.version,
    required this.title,
    required this.requiredShards,
    required this.data,
    required this.nonce,
  });

  /// Parse a shard from its JSON string (as stored in a QR code).
  factory Shard.parse(String payload) {
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid shard JSON: $e');
    }
    return Shard(
      version: (parsed['v'] as int?) ?? 0,
      title: parsed['t'] as String,
      requiredShards: parsed['r'] as int,
      data: parsed['d'] as String,
      nonce: parsed['n'] as String,
    );
  }

  /// Serialize this shard to a JSON string for QR code encoding.
  /// Escapes non-ASCII characters to \\uXXXX (matching web app behavior).
  String toJson() {
    final map = {'v': version, 't': title, 'r': requiredShards, 'd': data, 'n': nonce};
    final jsonStr = jsonEncode(map);
    // Escape non-ASCII chars to \uXXXX, matching the web app's behavior
    final sb = StringBuffer();
    for (final codeUnit in jsonStr.codeUnits) {
      if (codeUnit >= 0x7F && codeUnit <= 0xFFFF) {
        sb.write('\\u${codeUnit.toRadixString(16).padLeft(4, '0')}');
      } else {
        sb.writeCharCode(codeUnit);
      }
    }
    return sb.toString();
  }

  /// Validate that a list of shards are compatible for combining.
  /// Throws a descriptive error string if not.
  static void validateCompatibility(List<Shard> shards) {
    if (shards.isEmpty) return;
    final first = shards.first;
    for (final shard in shards.skip(1)) {
      if (shard.requiredShards != first.requiredShards) {
        throw 'Mismatching min shards requirement among shards!';
      }
      if (shard.nonce != first.nonce) {
        throw 'Nonces mismatch among shards!';
      }
      if (shard.title != first.title) {
        throw 'Titles mismatch among shards!';
      }
      if (shard.version != first.version) {
        throw 'Versions mismatch among shards!';
      }
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test test/shard_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/models/shard.dart banana_split_flutter/test/shard_test.dart
git commit -m "feat: add Shard model with v0/v1/v2 parsing and validation"
```

---

## Chunk 2: Crypto Pipeline

### Task 4: Crypto module — encrypt, decrypt, share, reconstruct

**Files:**
- Create: `banana_split_flutter/lib/crypto/crypto.dart`
- Create: `banana_split_flutter/test/crypto_test.dart`

- [ ] **Step 1: Write failing tests for crypto round-trip**

```dart
// banana_split_flutter/test/crypto_test.dart
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
        data: secret,
        title: title,
        passphrase: passphrase,
        totalShards: 5,
        requiredShards: 3,
      );

      expect(shardJsons.length, equals(5));

      // Parse and reconstruct with first 3
      final shards = shardJsons.sublist(0, 3).map(Shard.parse).toList();
      final recovered = await BananaCrypto.reconstruct(shards, passphrase);
      expect(recovered, equals(secret));
    });

    test('round-trip: different subset of shards', () async {
      const secret = 'My secret seed phrase';
      const title = 'wallet';
      const passphrase = 'test-pass';

      final shardJsons = await BananaCrypto.share(
        data: secret,
        title: title,
        passphrase: passphrase,
        totalShards: 5,
        requiredShards: 3,
      );

      // Use shards [1, 3, 4] (0-indexed)
      final shards = [shardJsons[1], shardJsons[3], shardJsons[4]]
          .map(Shard.parse)
          .toList();
      final recovered = await BananaCrypto.reconstruct(shards, passphrase);
      expect(recovered, equals(secret));
    });

    test('wrong passphrase throws', () async {
      const secret = 'secret';
      const title = 'test';

      final shardJsons = await BananaCrypto.share(
        data: secret,
        title: title,
        passphrase: 'correct-pass',
        totalShards: 3,
        requiredShards: 2,
      );

      final shards = shardJsons.sublist(0, 2).map(Shard.parse).toList();
      expect(
        () => BananaCrypto.reconstruct(shards, 'wrong-pass'),
        throwsA(predicate((e) => e.toString().contains('Unable to decrypt'))),
      );
    });

    test('generated shards are v2 format', () async {
      final shardJsons = await BananaCrypto.share(
        data: 'test',
        title: 'title',
        passphrase: 'pass',
        totalShards: 3,
        requiredShards: 2,
      );

      for (final json in shardJsons) {
        final shard = Shard.parse(json);
        expect(shard.version, equals(2));
      }
    });

    test('handles max secret length (1024 chars)', () async {
      final secret = 'A' * 1024;
      final shardJsons = await BananaCrypto.share(
        data: secret,
        title: 'big',
        passphrase: 'pass',
        totalShards: 3,
        requiredShards: 2,
      );

      final shards = shardJsons.sublist(0, 2).map(Shard.parse).toList();
      final recovered = await BananaCrypto.reconstruct(shards, 'pass');
      expect(recovered, equals(secret));
    });

    test('minimum shard count: 3 total, 2 required', () async {
      final shardJsons = await BananaCrypto.share(
        data: 'min',
        title: 'min-test',
        passphrase: 'pass',
        totalShards: 3,
        requiredShards: 2,
      );
      expect(shardJsons.length, equals(3));
    });
  });

  group('BananaCrypto v0/v1 compatibility', () {
    // These test vectors should be generated from the web app.
    // For now, test that v1 and v2 use the same encoding path.
    test('v1 shard can be reconstructed as v2 path', () async {
      // Generate v2 shards, manually change version to 1, verify still works
      // (v1 and v2 share identical encoding)
      const secret = 'compat-test';
      const title = 'compat';
      const passphrase = 'pass';

      final shardJsons = await BananaCrypto.share(
        data: secret,
        title: title,
        passphrase: passphrase,
        totalShards: 3,
        requiredShards: 2,
      );

      // Parse as v2, reconstruct — works
      final v2Shards = shardJsons.sublist(0, 2).map(Shard.parse).toList();
      expect(await BananaCrypto.reconstruct(v2Shards, passphrase), equals(secret));

      // Fake them as v1 — should still work since encoding is identical
      final v1Shards = v2Shards
          .map((s) => Shard(
                version: 1,
                title: s.title,
                requiredShards: s.requiredShards,
                data: s.data,
                nonce: s.nonce,
              ))
          .toList();
      expect(await BananaCrypto.reconstruct(v1Shards, passphrase), equals(secret));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test test/crypto_test.dart
```

Expected: FAIL — `crypto.dart` doesn't exist yet.

- [ ] **Step 3: Implement BananaCrypto class**

```dart
// banana_split_flutter/lib/crypto/crypto.dart
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pinenacl/secret.dart';
import 'package:pinenacl/api.dart';
import 'package:pinenacl/tweetnacl.dart';
import 'package:pointycastle/export.dart';

import 'package:banana_split_flutter/crypto/shamir.dart';
import 'package:banana_split_flutter/models/shard.dart';

class BananaCrypto {
  BananaCrypto._();

  /// SHA-512 hash of a string (same as tweetnacl's crypto_hash).
  static Uint8List _hashString(String str) {
    final data = Uint8List.fromList(utf8.encode(str));
    return TweetNaCl.crypto_hash(Uint8List(64), data);
  }

  /// Hex-encode a byte array.
  static String _hexify(Uint8List arr) {
    return arr.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Decode a hex string to bytes.
  static Uint8List _dehexify(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16);
    }
    return result;
  }

  /// Derive a 32-byte key using scrypt.
  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final scrypt = KeyDerivator('scrypt')
      ..init(ScryptParameters(
        1 << 15, // N = 32768
        8,       // r
        1,       // p
        32,      // dkLen
        salt,
      ));
    return scrypt.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// Encrypt data with NaCl secretbox.
  static ({Uint8List value, Uint8List nonce, Uint8List salt}) _encrypt(
    String data,
    Uint8List salt,
    String passphrase,
  ) {
    final key = _deriveKey(passphrase, salt);
    final nonce = PineNaClUtils.randombytes(24);
    final plaintext = Uint8List.fromList(utf8.encode(data));

    final box = SecretBox(key);
    final encrypted = box.encrypt(plaintext, nonce: nonce);
    // encrypted.cipherText includes the MAC appended by pinenacl.
    // We need raw secretbox output: tweetnacl format = MAC + ciphertext
    // pinenacl's EncryptedMessage: nonce + MAC + ciphertext
    // We want just MAC + ciphertext (what tweetnacl.secretbox returns)
    return (
      value: Uint8List.fromList(encrypted.cipherText.toList()),
      nonce: nonce,
      salt: salt,
    );
  }

  /// Decrypt data with NaCl secretbox. Returns null on failure.
  static Uint8List? _decrypt(
    Uint8List data,
    Uint8List salt,
    String passphrase,
    Uint8List nonce,
  ) {
    final key = _deriveKey(passphrase, salt);
    final box = SecretBox(key);
    try {
      final decrypted = box.decrypt(
        EncryptedMessage(
          nonce: nonce,
          cipherText: data,
        ),
      );
      return Uint8List.fromList(decrypted);
    } catch (_) {
      return null;
    }
  }

  /// Split a secret into shards. Returns a list of JSON strings (one per shard).
  /// Runs heavy crypto (scrypt) in a separate isolate to avoid blocking UI.
  static Future<List<String>> share({
    required String data,
    required String title,
    required String passphrase,
    required int totalShards,
    required int requiredShards,
  }) async {
    return Isolate.run(() {
      final salt = _hashString(title);
      final encrypted = _encrypt(data, salt, passphrase);
      final nonceB64 = base64Encode(encrypted.nonce);
      final hexEncrypted = _hexify(encrypted.value);

      final shamir = Shamir(bits: 8);
      final shamirShares = shamir.share(hexEncrypted, totalShards, requiredShards);

      return shamirShares.map((shamirShard) {
        // First char is base36 bitfield size, rest is hex share data
        final bitfieldChar = shamirShard[0];
        final hexData = shamirShard.substring(1);
        final encodedShard = bitfieldChar + base64Encode(_dehexify(hexData));

        return Shard(
          version: 2,
          title: title,
          requiredShards: requiredShards,
          data: encodedShard,
          nonce: nonceB64,
        ).toJson();
      }).toList();
    });
  }

  /// Reconstruct a secret from shards and a passphrase.
  /// Runs heavy crypto (scrypt) in a separate isolate to avoid blocking UI.
  static Future<String> reconstruct(
    List<Shard> shardObjects,
    String passphrase,
  ) async {
    Shard.validateCompatibility(shardObjects);
    final first = shardObjects.first;

    if (shardObjects.length < first.requiredShards) {
      throw 'Not enough shards, need ${first.requiredShards} '
          'but only ${shardObjects.length} provided';
    }

    // Collect serializable data for the isolate
    final shardDataList = shardObjects.map((s) => {
      'version': s.version,
      'data': s.data,
      'nonce': s.nonce,
      'title': s.title,
    }).toList();
    final version = first.version;

    return Isolate.run(() {
      Uint8List? decryptedMsg;
      final shamir = Shamir(bits: 8);

      switch (version) {
        case 0:
          // v0: hex-encoded nonces, raw hex shard data
          final shardData = shardDataList.map((s) => s['data'] as String).toList();
          final encryptedHex = shamir.combine(shardData);
          final encrypted = _dehexify(encryptedHex);
          final nonce = _dehexify(shardDataList.first['nonce'] as String);
          final salt = _hashString(shardDataList.first['title'] as String);
          decryptedMsg = _decrypt(encrypted, salt, passphrase, nonce);
          break;
        case 1:
        case 2:
          // v1/v2: base64-encoded nonces, bitfield char + base64 shard data
          final shardData = shardDataList.map((s) {
            final d = s['data'] as String;
            final bitfieldChar = d[0];
            final b64Data = d.substring(1);
            return bitfieldChar + _hexify(base64Decode(b64Data));
          }).toList();
          final encryptedHex = shamir.combine(shardData);
          final encrypted = _dehexify(encryptedHex);
          final nonce = base64Decode(shardDataList.first['nonce'] as String);
          final salt = _hashString(shardDataList.first['title'] as String);
          decryptedMsg = _decrypt(encrypted, salt, passphrase, Uint8List.fromList(nonce));
          break;
        default:
          throw 'Version is not supported!';
      }

      if (decryptedMsg == null) {
        throw 'Unable to decrypt the secret';
      }
      return utf8.decode(decryptedMsg);
    });
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test test/crypto_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/crypto/crypto.dart banana_split_flutter/test/crypto_test.dart
git commit -m "feat: implement crypto pipeline (scrypt + NaCl + Shamir)"
```

---

### Task 5: Passphrase generation

**Files:**
- Create: `banana_split_flutter/lib/crypto/passphrase.dart`
- Create: `banana_split_flutter/assets/wordlist.txt`
- Create: `banana_split_flutter/test/passphrase_test.dart`

- [ ] **Step 1: Extract word list from the web app**

```bash
cd /home/mezinster/banana_split
# Extract just the words (lines between [ and ]) from passPhrase.ts
sed -n '/wordlist: \[/,/\]/p' src/util/passPhrase.ts | grep '"' | sed 's/.*"\(.*\)".*/\1/' > banana_split_flutter/assets/wordlist.txt
```

Verify: the file should have 7,778 words, one per line.

```bash
wc -l banana_split_flutter/assets/wordlist.txt
```

Expected: 7778 lines.

- [ ] **Step 2: Write failing tests**

```dart
// banana_split_flutter/test/passphrase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/crypto/passphrase.dart';

void main() {
  group('PassphraseGenerator', () {
    test('generates correct number of words', () {
      final wordlist = List.generate(2048, (i) => 'word$i');
      final generator = PassphraseGenerator(wordlist);
      final result = generator.generate(4);
      final words = result.split('-');
      expect(words.length, equals(4));
    });

    test('words are hyphen-separated', () {
      final wordlist = List.generate(2048, (i) => 'word$i');
      final generator = PassphraseGenerator(wordlist);
      final result = generator.generate(4);
      expect(result, contains('-'));
      expect(result.split('-').every((w) => w.startsWith('word')), isTrue);
    });

    test('uses modulo 2048 for index selection', () {
      final wordlist = List.generate(7778, (i) => 'w$i');
      final generator = PassphraseGenerator(wordlist);
      // Generate many passphrases and verify all words come from first 2048
      for (int i = 0; i < 20; i++) {
        final result = generator.generate(4);
        for (final word in result.split('-')) {
          final idx = int.parse(word.substring(1));
          expect(idx, lessThan(2048));
        }
      }
    });

    test('different calls produce different passphrases', () {
      final wordlist = List.generate(2048, (i) => 'word$i');
      final generator = PassphraseGenerator(wordlist);
      final results = List.generate(10, (_) => generator.generate(4));
      // At least some should differ (probabilistic but virtually certain)
      expect(results.toSet().length, greaterThan(1));
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test test/passphrase_test.dart
```

Expected: FAIL.

- [ ] **Step 4: Implement PassphraseGenerator**

```dart
// banana_split_flutter/lib/crypto/passphrase.dart
import 'dart:math';

class PassphraseGenerator {
  final List<String> _wordlist;
  final Random _rng = Random.secure();

  PassphraseGenerator(this._wordlist);

  /// Generate a passphrase of [wordCount] random words, hyphen-separated.
  /// Uses modulo 2048 indexing to match the web app's behavior.
  String generate(int wordCount) {
    final words = <String>[];
    for (int i = 0; i < wordCount; i++) {
      final index = _rng.nextInt(65536) % 2048;
      words.add(_wordlist[index]);
    }
    return words.join('-');
  }

  /// Load a PassphraseGenerator from a newline-separated word list string.
  factory PassphraseGenerator.fromString(String wordlistContent) {
    final words = wordlistContent
        .split('\n')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    return PassphraseGenerator(words);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test test/passphrase_test.dart
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/crypto/passphrase.dart banana_split_flutter/assets/wordlist.txt banana_split_flutter/test/passphrase_test.dart
git commit -m "feat: add passphrase generator with word list"
```

---

## Chunk 3: State Management + App Shell

### Task 6: State notifiers (CreateNotifier, RestoreNotifier)

**Files:**
- Create: `banana_split_flutter/lib/state/create_notifier.dart`
- Create: `banana_split_flutter/lib/state/restore_notifier.dart`

- [ ] **Step 1: Implement CreateNotifier**

```dart
// banana_split_flutter/lib/state/create_notifier.dart
import 'package:flutter/foundation.dart';
import 'package:banana_split_flutter/crypto/crypto.dart';
import 'package:banana_split_flutter/crypto/passphrase.dart';

class CreateNotifier extends ChangeNotifier {
  final PassphraseGenerator _passphraseGen;

  String title = '';
  String secret = '';
  int totalShards = 5;
  String passphrase = '';
  List<String> generatedShards = [];
  bool isGenerating = false;
  bool showResults = false;
  String? error;
  bool useManualPassphrase = false;

  CreateNotifier(this._passphraseGen) {
    regeneratePassphrase();
  }

  int get requiredShards => (totalShards ~/ 2) + 1;
  bool get secretTooLong => secret.length > 1024;
  bool get canGenerate =>
      title.isNotEmpty &&
      secret.isNotEmpty &&
      !secretTooLong &&
      totalShards >= 3 &&
      totalShards <= 255 &&
      passphrase.isNotEmpty &&
      (!useManualPassphrase || passphrase.length >= 8);

  void updateTitle(String value) {
    title = value;
    notifyListeners();
  }

  void updateSecret(String value) {
    secret = value;
    notifyListeners();
  }

  void updateTotalShards(int value) {
    totalShards = value.clamp(3, 255);
    notifyListeners();
  }

  void updatePassphrase(String value) {
    passphrase = value;
    notifyListeners();
  }

  void toggleManualPassphrase() {
    useManualPassphrase = !useManualPassphrase;
    if (!useManualPassphrase) {
      regeneratePassphrase();
    } else {
      passphrase = '';
    }
    notifyListeners();
  }

  void regeneratePassphrase() {
    passphrase = _passphraseGen.generate(4);
    notifyListeners();
  }

  Future<void> generate() async {
    if (!canGenerate) return;
    isGenerating = true;
    error = null;
    notifyListeners();

    try {
      generatedShards = await BananaCrypto.share(
        data: secret,
        title: title,
        passphrase: passphrase,
        totalShards: totalShards,
        requiredShards: requiredShards,
      );
      showResults = true;
    } catch (e) {
      error = e.toString();
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  void backToEdit() {
    showResults = false;
    generatedShards = [];
    notifyListeners();
  }

  void reset() {
    title = '';
    secret = '';
    totalShards = 5;
    generatedShards = [];
    isGenerating = false;
    showResults = false;
    error = null;
    useManualPassphrase = false;
    regeneratePassphrase();
    notifyListeners();
  }
}
```

- [ ] **Step 2: Implement RestoreNotifier**

```dart
// banana_split_flutter/lib/state/restore_notifier.dart
import 'package:flutter/foundation.dart';
import 'package:banana_split_flutter/crypto/crypto.dart';
import 'package:banana_split_flutter/models/shard.dart';

class RestoreNotifier extends ChangeNotifier {
  final List<Shard> _shards = [];
  final Set<String> _rawCodes = {};
  String passphrase = '';
  String? recoveredSecret;
  bool isDecrypting = false;
  String? error;

  List<Shard> get shards => List.unmodifiable(_shards);
  int get scannedCount => _shards.length;
  int? get requiredCount => _shards.isEmpty ? null : _shards.first.requiredShards;
  String? get title => _shards.isEmpty ? null : _shards.first.title;
  bool get needMoreShards =>
      requiredCount == null || _shards.length < requiredCount!;

  /// Add a scanned QR code. Returns null on success, or an error message.
  String? addShard(String rawQrData) {
    if (rawQrData.isEmpty) return null;

    if (_rawCodes.contains(rawQrData)) {
      return 'Shard already scanned';
    }

    Shard parsed;
    try {
      parsed = Shard.parse(rawQrData);
    } catch (e) {
      return 'Invalid QR code: $e';
    }

    // Validate against existing shards
    if (_shards.isNotEmpty) {
      final first = _shards.first;
      if (parsed.title != first.title) {
        return 'This shard belongs to a different split';
      }
      if (parsed.nonce != first.nonce) {
        return 'Shard data inconsistency';
      }
      if (parsed.requiredShards != first.requiredShards) {
        return 'Shard requirements inconsistency';
      }
      if (parsed.version != first.version) {
        return 'Shards from different versions cannot be combined';
      }
    }

    _rawCodes.add(rawQrData);
    _shards.add(parsed);
    notifyListeners();
    return null;
  }

  void updatePassphrase(String value) {
    passphrase = value;
    notifyListeners();
  }

  Future<void> reconstruct() async {
    if (passphrase.isEmpty || needMoreShards) return;

    isDecrypting = true;
    error = null;
    notifyListeners();

    try {
      // Normalize passphrase: split by spaces, filter empty, rejoin with hyphens
      final normalized = passphrase
          .split(' ')
          .where((s) => s.isNotEmpty)
          .join('-');

      recoveredSecret = await BananaCrypto.reconstruct(_shards, normalized);
    } catch (e) {
      error = e.toString().contains('Unable to decrypt')
          ? 'Wrong passphrase or corrupted data'
          : e.toString();
    } finally {
      isDecrypting = false;
      notifyListeners();
    }
  }

  void reset() {
    _shards.clear();
    _rawCodes.clear();
    passphrase = '';
    recoveredSecret = null;
    isDecrypting = false;
    error = null;
    notifyListeners();
  }
}
```

- [ ] **Step 3: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/state/
git commit -m "feat: add CreateNotifier and RestoreNotifier state management"
```

---

### Task 7: App shell with bottom navigation

**Files:**
- Create: `banana_split_flutter/lib/screens/create_screen.dart` (placeholder)
- Create: `banana_split_flutter/lib/screens/restore_screen.dart` (placeholder)
- Create: `banana_split_flutter/lib/screens/about_screen.dart` (placeholder)
- Modify: `banana_split_flutter/lib/main.dart`

- [ ] **Step 1: Create placeholder screens**

```dart
// banana_split_flutter/lib/screens/create_screen.dart
import 'package:flutter/material.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Create — coming soon'));
  }
}
```

```dart
// banana_split_flutter/lib/screens/restore_screen.dart
import 'package:flutter/material.dart';

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Restore — coming soon'));
  }
}
```

```dart
// banana_split_flutter/lib/screens/about_screen.dart
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Banana Split',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'Banana Split uses Shamir\'s Secret Sharing to split your secret '
            '(e.g., a paper backup) into N pieces. Only a majority of those '
            'pieces (N/2 + 1) are needed to recover the secret.',
          ),
          const SizedBox(height: 16),
          const Text(
            'For example: split your backup into 5 pieces and give them to '
            '5 friends. Any 3 friends can reconstruct it, but any 2 friends '
            'will know nothing.',
          ),
          const SizedBox(height: 16),
          Text(
            'How to create a split',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('1. Go to the Create tab and enter your secret.'),
          const Text('2. Choose the number of shards.'),
          const Text('3. Note the auto-generated passphrase — you\'ll need it to recover.'),
          const Text('4. Save or share the QR codes with your trusted parties.'),
          const Text('5. Write the passphrase on every printout by hand.'),
          const SizedBox(height: 16),
          Text(
            'How to restore',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('1. Go to the Restore tab.'),
          const Text('2. Scan a majority of QR codes using camera or gallery.'),
          const Text('3. Enter the passphrase.'),
          const Text('4. Your secret is restored.'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Implement main.dart with Provider setup and bottom nav**

```dart
// banana_split_flutter/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:banana_split_flutter/crypto/passphrase.dart';
import 'package:banana_split_flutter/state/create_notifier.dart';
import 'package:banana_split_flutter/state/restore_notifier.dart';
import 'package:banana_split_flutter/screens/create_screen.dart';
import 'package:banana_split_flutter/screens/restore_screen.dart';
import 'package:banana_split_flutter/screens/about_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final wordlistStr = await rootBundle.loadString('assets/wordlist.txt');
  final passphraseGen = PassphraseGenerator.fromString(wordlistStr);

  runApp(BananaSplitApp(passphraseGen: passphraseGen));
}

class BananaSplitApp extends StatelessWidget {
  final PassphraseGenerator passphraseGen;

  const BananaSplitApp({super.key, required this.passphraseGen});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CreateNotifier(passphraseGen)),
        ChangeNotifierProvider(create: (_) => RestoreNotifier()),
      ],
      child: MaterialApp(
        title: 'Banana Split',
        theme: ThemeData(
          colorSchemeSeed: Colors.amber,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.amber,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    CreateScreen(),
    RestoreScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Banana Split')),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Create'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Restore'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'About'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify app builds**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter analyze
```

Expected: No analysis issues.

- [ ] **Step 4: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/
git commit -m "feat: add app shell with bottom navigation and Provider setup"
```

---

## Chunk 4: Create Screen UI

### Task 8: Passphrase field widget

**Files:**
- Create: `banana_split_flutter/lib/widgets/passphrase_field.dart`

- [ ] **Step 1: Implement passphrase field widget**

```dart
// banana_split_flutter/lib/widgets/passphrase_field.dart
import 'package:flutter/material.dart';

class PassphraseField extends StatelessWidget {
  final String passphrase;
  final bool isManual;
  final ValueChanged<String> onChanged;
  final VoidCallback onRegenerate;
  final VoidCallback onToggleMode;

  const PassphraseField({
    super.key,
    required this.passphrase,
    required this.isManual,
    required this.onChanged,
    required this.onRegenerate,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Passphrase', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: onToggleMode,
              child: Text(isManual ? 'Auto-generate' : 'Enter manually'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isManual)
          TextField(
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter your passphrase (min 8 characters)',
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    passphrase,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh),
                tooltip: 'Generate new passphrase',
              ),
            ],
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/widgets/passphrase_field.dart
git commit -m "feat: add PassphraseField widget with auto/manual toggle"
```

---

### Task 9: QR grid widget

**Files:**
- Create: `banana_split_flutter/lib/widgets/qr_grid.dart`

- [ ] **Step 1: Implement QR grid widget**

```dart
// banana_split_flutter/lib/widgets/qr_grid.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:banana_split_flutter/services/export_service.dart';

class QrGrid extends StatelessWidget {
  final List<String> shardJsons;
  final String title;

  const QrGrid({
    super.key,
    required this.shardJsons,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: shardJsons.length,
      itemBuilder: (context, index) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(
                  'Shard ${index + 1} of ${shardJsons.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: QrImageView(
                    data: shardJsons[index],
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                // Per-shard save/share actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.save_alt, size: 18),
                      tooltip: 'Save this shard',
                      onPressed: () async {
                        try {
                          final path = await ExportService.saveSinglePng(
                            shardJson: shardJsons[index],
                            title: title,
                            shardIndex: index + 1,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Saved shard ${index + 1}')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 18),
                      tooltip: 'Share this shard',
                      onPressed: () async {
                        try {
                          await ExportService.shareSingleShard(
                            shardJson: shardJsons[index],
                            title: title,
                            shardIndex: index + 1,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Share failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/widgets/qr_grid.dart
git commit -m "feat: add QrGrid widget for shard display"
```

---

### Task 10: Full Create screen

**Files:**
- Modify: `banana_split_flutter/lib/screens/create_screen.dart`

- [ ] **Step 1: Implement the full Create screen with two-step wizard**

```dart
// banana_split_flutter/lib/screens/create_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:banana_split_flutter/state/create_notifier.dart';
import 'package:banana_split_flutter/widgets/passphrase_field.dart';
import 'package:banana_split_flutter/widgets/qr_grid.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CreateNotifier>(
      builder: (context, notifier, _) {
        if (notifier.isGenerating) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Encrypting...'),
              ],
            ),
          );
        }

        if (notifier.showResults) {
          return _ResultsView(notifier: notifier);
        }

        return _InputForm(notifier: notifier);
      },
    );
  }
}

class _InputForm extends StatefulWidget {
  final CreateNotifier notifier;
  const _InputForm({required this.notifier});

  @override
  State<_InputForm> createState() => _InputFormState();
}

class _InputFormState extends State<_InputForm> {
  late final TextEditingController _shardsController;

  @override
  void initState() {
    super.initState();
    _shardsController = TextEditingController(
      text: widget.notifier.totalShards.toString(),
    );
  }

  @override
  void dispose() {
    _shardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = widget.notifier;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create a secret split',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),

          // 1. Title
          TextField(
            onChanged: notifier.updateTitle,
            decoration: const InputDecoration(
              labelText: '1. Name of your split',
              border: OutlineInputBorder(),
              hintText: "Ex: 'My Bitcoin seed phrase'",
            ),
          ),
          const SizedBox(height: 16),

          // 2. Secret
          TextField(
            onChanged: notifier.updateSecret,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: '2. Secret',
              border: const OutlineInputBorder(),
              hintText: 'Your secret goes here',
              errorText: notifier.secretTooLong
                  ? 'Inputs longer than 1024 characters make QR codes illegible'
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // 3. Shards
          Row(
            children: [
              Text('3. Shards — will require any ${notifier.requiredShards} out of '),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  controller: _shardsController,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null) notifier.updateTotalShards(n);
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 4. Passphrase
          PassphraseField(
            passphrase: notifier.passphrase,
            isManual: notifier.useManualPassphrase,
            onChanged: notifier.updatePassphrase,
            onRegenerate: notifier.regeneratePassphrase,
            onToggleMode: notifier.toggleManualPassphrase,
          ),
          const SizedBox(height: 24),

          if (notifier.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(notifier.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),

          FilledButton(
            onPressed: notifier.canGenerate ? notifier.generate : null,
            child: const Text('Generate QR codes!'),
          ),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final CreateNotifier notifier;
  const _ResultsView({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Passphrase reminder
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your recovery passphrase:',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SelectableText(
                    notifier.passphrase,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Write this passphrase on every printout by hand!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: notifier.backToEdit,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: implement save (Task 12)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Save coming soon')),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: implement share (Task 12)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share coming soon')),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // QR Grid
          QrGrid(
            shardJsons: notifier.generatedShards,
            title: notifier.title,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify app builds**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter analyze
```

Expected: No analysis issues.

- [ ] **Step 3: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/screens/create_screen.dart
git commit -m "feat: implement Create screen with input form and results view"
```

---

## Chunk 5: Restore Screen UI

### Task 11: Shard scanner widget

**Files:**
- Create: `banana_split_flutter/lib/widgets/shard_scanner.dart`

- [ ] **Step 1: Implement shard scanner widget**

```dart
// banana_split_flutter/lib/widgets/shard_scanner.dart
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zxing2/qrcode.dart';
import 'package:image/image.dart' as img;

class ShardScanner extends StatefulWidget {
  final void Function(String rawData) onScanned;
  final int scannedCount;
  final int? requiredCount;

  const ShardScanner({
    super.key,
    required this.onScanned,
    required this.scannedCount,
    this.requiredCount,
  });

  @override
  State<ShardScanner> createState() => _ShardScannerState();
}

class _ShardScannerState extends State<ShardScanner> {
  MobileScannerController? _cameraController;
  bool _cameraSupported = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // On Windows/Linux, camera is not reliably supported
    if (Platform.isWindows || Platform.isLinux) return;

    // Request camera permission on Android/macOS
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _cameraController = MobileScannerController();
      setState(() => _cameraSupported = true);
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        widget.onScanned(raw);
      }
    }
  }

  /// Decode QR code from an image file using zxing2 (works on all platforms).
  String? _decodeQrFromFile(String path) {
    final bytes = File(path).readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final luminances = Int32List(image.width * image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        luminances[y * image.width + x] =
            (pixel.r.toInt() * 299 + pixel.g.toInt() * 587 + pixel.b.toInt() * 114) ~/ 1000;
      }
    }

    try {
      final source = RGBLuminanceSource(
        image.width, image.height, luminances,
      );
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final reader = QRCodeReader();
      final result = reader.decode(bitmap);
      return result.text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Use zxing2 for QR decoding — works on all platforms including desktop
    final result = _decodeQrFromFile(image.path);
    if (result != null && result.isNotEmpty) {
      widget.onScanned(result);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR code found in image')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressText = widget.requiredCount != null
        ? '${widget.scannedCount} of ${widget.requiredCount} scanned'
        : 'Scan first shard...';

    return Column(
      children: [
        // Progress indicator
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(progressText,
              style: Theme.of(context).textTheme.titleMedium),
        ),

        // Camera preview (if supported)
        if (_cameraSupported && _cameraController != null)
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                controller: _cameraController!,
                onDetect: _onDetect,
              ),
            ),
          )
        else if (_permissionDenied)
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Camera permission denied.\n'
                    'Grant camera access in Settings, or import QR images below.'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          )
        else
          Container(
            height: 200,
            alignment: Alignment.center,
            child: const Text('Camera not available on this platform.\n'
                'Use the import button below to load QR code images.'),
          ),

        const SizedBox(height: 16),

        // Gallery import button
        OutlinedButton.icon(
          onPressed: _importFromGallery,
          icon: const Icon(Icons.photo_library),
          label: const Text('Import from gallery'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/widgets/shard_scanner.dart
git commit -m "feat: add ShardScanner widget with camera and gallery import"
```

---

### Task 12: Full Restore screen

**Files:**
- Modify: `banana_split_flutter/lib/screens/restore_screen.dart`

- [ ] **Step 1: Implement the full Restore screen**

```dart
// banana_split_flutter/lib/screens/restore_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:banana_split_flutter/state/restore_notifier.dart';
import 'package:banana_split_flutter/widgets/shard_scanner.dart';

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RestoreNotifier>(
      builder: (context, notifier, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                notifier.title != null
                    ? 'Combine shards for "${notifier.title}"'
                    : 'Combine shards',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              if (notifier.recoveredSecret != null)
                _RecoveredView(notifier: notifier)
              else if (notifier.needMoreShards)
                _ScannerView(notifier: notifier)
              else
                _PassphraseView(notifier: notifier),

              const SizedBox(height: 16),

              // Reset button (always visible once scanning has started)
              if (notifier.scannedCount > 0 || notifier.recoveredSecret != null)
                OutlinedButton.icon(
                  onPressed: notifier.reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Start over'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerView extends StatelessWidget {
  final RestoreNotifier notifier;
  const _ScannerView({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ShardScanner(
      scannedCount: notifier.scannedCount,
      requiredCount: notifier.requiredCount,
      onScanned: (rawData) {
        final error = notifier.addShard(rawData);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shard ${notifier.scannedCount} added'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }
}

class _PassphraseView extends StatelessWidget {
  final RestoreNotifier notifier;
  const _PassphraseView({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('All shards collected!'),
        const SizedBox(height: 16),
        TextField(
          onChanged: notifier.updatePassphrase,
          onSubmitted: (_) => notifier.reconstruct(),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Passphrase',
            border: OutlineInputBorder(),
            hintText: 'Type your passphrase',
          ),
        ),
        const SizedBox(height: 16),

        if (notifier.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(notifier.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),

        if (notifier.isDecrypting)
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Decrypting...'),
              ],
            ),
          )
        else
          FilledButton(
            onPressed: notifier.passphrase.isNotEmpty
                ? notifier.reconstruct
                : null,
            child: const Text('Reconstruct Secret'),
          ),
      ],
    );
  }
}

class _RecoveredView extends StatelessWidget {
  final RestoreNotifier notifier;
  const _RecoveredView({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recovered Secret',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(
              notifier.recoveredSecret!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify app builds**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter analyze
```

Expected: No analysis issues.

- [ ] **Step 3: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/screens/restore_screen.dart
git commit -m "feat: implement Restore screen with scanner, passphrase, and results"
```

---

## Chunk 6: Export Service + Final Integration

### Task 13: Export service (save PNG/PDF, share)

**Files:**
- Create: `banana_split_flutter/lib/services/export_service.dart`

- [ ] **Step 1: Implement export service**

```dart
// banana_split_flutter/lib/services/export_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ExportService {
  ExportService._();

  /// Generate a QR code as PNG bytes.
  static Future<Uint8List> _qrToPng(String data, {int size = 300}) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
    );
    final image = await qrPainter.toImage(size.toDouble());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Save all shards as individual PNG files. Returns the directory path.
  static Future<String> saveAsPngs({
    required List<String> shardJsons,
    required String title,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final subDir = Directory('${dir.path}/banana_split/$safeTitle');
    await subDir.create(recursive: true);

    for (int i = 0; i < shardJsons.length; i++) {
      final pngBytes = await _qrToPng(shardJsons[i]);
      final file = File('${subDir.path}/${safeTitle}_shard_${i + 1}.png');
      await file.writeAsBytes(pngBytes);
    }

    return subDir.path;
  }

  /// Save all shards as a single PDF file. Returns the file path.
  static Future<String> saveAsPdf({
    required List<String> shardJsons,
    required String title,
    required int requiredShards,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final subDir = Directory('${dir.path}/banana_split');
    await subDir.create(recursive: true);

    final pdf = pw.Document();

    for (int i = 0; i < shardJsons.length; i++) {
      final pngBytes = await _qrToPng(shardJsons[i], size: 300);
      final image = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 16),
                  pw.Text('Shard ${i + 1} of ${shardJsons.length}',
                      style: const pw.TextStyle(fontSize: 18)),
                  pw.Text('Requires $requiredShards shards to reconstruct',
                      style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 24),
                  pw.Image(image, width: 300, height: 300),
                  pw.SizedBox(height: 24),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 2),
                    ),
                    child: pw.Text(
                      'Write your passphrase here: ___________________________',
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    final filePath = '${subDir.path}/${safeTitle}_shards.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  /// Save a single shard as PNG. Returns the file path.
  static Future<String> saveSinglePng({
    required String shardJson,
    required String title,
    required int shardIndex,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final subDir = Directory('${dir.path}/banana_split/$safeTitle');
    await subDir.create(recursive: true);

    final pngBytes = await _qrToPng(shardJson);
    final file = File('${subDir.path}/${safeTitle}_shard_$shardIndex.png');
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  /// Share shard files via OS share sheet.
  static Future<void> shareShards({
    required List<String> shardJsons,
    required String title,
  }) async {
    final dirPath = await saveAsPngs(shardJsons: shardJsons, title: title);
    final dir = Directory(dirPath);
    final files = await dir.list().where((f) => f.path.endsWith('.png')).toList();
    final xFiles = files.map((f) => XFile(f.path)).toList();

    try {
      await Share.shareXFiles(xFiles, subject: 'Banana Split: $title');
    } catch (_) {
      // Share sheet unavailable — files already saved, caller can notify user
      rethrow;
    }
  }

  /// Share a single shard via OS share sheet.
  static Future<void> shareSingleShard({
    required String shardJson,
    required String title,
    required int shardIndex,
  }) async {
    final path = await saveSinglePng(
      shardJson: shardJson,
      title: title,
      shardIndex: shardIndex,
    );
    await Share.shareXFiles([XFile(path)], subject: 'Banana Split: $title - Shard $shardIndex');
  }
}
```

- [ ] **Step 2: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/services/export_service.dart
git commit -m "feat: add ExportService for PNG, PDF, and share sheet export"
```

---

### Task 14: Wire export buttons into Create screen

**Files:**
- Modify: `banana_split_flutter/lib/screens/create_screen.dart`

- [ ] **Step 1: Replace TODO save/share callbacks in _ResultsView**

In `banana_split_flutter/lib/screens/create_screen.dart`, replace the two `onPressed` callbacks in the Save and Share buttons that currently show "coming soon" snackbars:

Save button `onPressed`:
```dart
onPressed: () async {
  try {
    final path = await ExportService.saveAsPdf(
      shardJsons: notifier.generatedShards,
      title: notifier.title,
      requiredShards: notifier.requiredShards,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $path')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
},
```

Share button `onPressed`:
```dart
onPressed: () async {
  try {
    await ExportService.shareShards(
      shardJsons: notifier.generatedShards,
      title: notifier.title,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }
},
```

Add import at top of file:
```dart
import 'package:banana_split_flutter/services/export_service.dart';
```

- [ ] **Step 2: Verify app builds**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter analyze
```

Expected: No analysis issues.

- [ ] **Step 3: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/lib/screens/create_screen.dart
git commit -m "feat: wire save/share export buttons in Create screen"
```

---

### Task 15: Android permissions configuration

**Files:**
- Modify: `banana_split_flutter/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add camera permission to AndroidManifest.xml**

Add inside the `<manifest>` tag, before `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

- [ ] **Step 2: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/android/app/src/main/AndroidManifest.xml
git commit -m "feat: add camera permission for Android"
```

---

### Task 16: End-to-end smoke test

**Files:**
- Create: `banana_split_flutter/test/integration_test.dart`

- [ ] **Step 1: Write an end-to-end crypto integration test**

This test exercises the full pipeline: generate shards, parse them, reconstruct — verifying the complete flow works with real package interactions.

```dart
// banana_split_flutter/test/integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/crypto/crypto.dart';
import 'package:banana_split_flutter/crypto/passphrase.dart';
import 'package:banana_split_flutter/models/shard.dart';

void main() {
  group('End-to-end integration', () {
    test('full create-then-restore flow', () async {
      // Generate passphrase
      final wordlist = List.generate(2048, (i) => 'word$i');
      final gen = PassphraseGenerator(wordlist);
      final passphrase = gen.generate(4);

      // Create shards
      const secret = 'This is my very important seed phrase that must be kept safe';
      const title = 'Integration Test Wallet';

      final shardJsons = await BananaCrypto.share(
        data: secret,
        title: title,
        passphrase: passphrase,
        totalShards: 5,
        requiredShards: 3,
      );

      expect(shardJsons.length, equals(5));

      // Parse shards (simulates QR scanning)
      final shards = <Shard>[];
      for (final json in [shardJsons[0], shardJsons[2], shardJsons[4]]) {
        final shard = Shard.parse(json);
        expect(shard.version, equals(2));
        expect(shard.title, equals(title));
        shards.add(shard);
      }

      // Validate compatibility
      Shard.validateCompatibility(shards);

      // Reconstruct
      final recovered = await BananaCrypto.reconstruct(shards, passphrase);
      expect(recovered, equals(secret));
    });

    test('passphrase normalization: spaces to hyphens', () async {
      const passphrase = 'alpha-bravo-charlie-delta';
      const passphraseWithSpaces = 'alpha bravo  charlie delta';

      final shardJsons = await BananaCrypto.share(
        data: 'test',
        title: 'normalize',
        passphrase: passphrase,
        totalShards: 3,
        requiredShards: 2,
      );

      final shards = shardJsons.sublist(0, 2).map(Shard.parse).toList();

      // Normalize like RestoreNotifier does
      final normalized = passphraseWithSpaces
          .split(' ')
          .where((s) => s.isNotEmpty)
          .join('-');

      final recovered = await BananaCrypto.reconstruct(shards, normalized);
      expect(recovered, equals('test'));
    });

    test('maximum shard count (255 total)', () async {
      final shardJsons = await BananaCrypto.share(
        data: 'max shards test',
        title: 'max',
        passphrase: 'pass',
        totalShards: 255,
        requiredShards: 128,
      );
      expect(shardJsons.length, equals(255));

      // Reconstruct with exactly 128 shards
      final shards = shardJsons.sublist(0, 128).map(Shard.parse).toList();
      final recovered = await BananaCrypto.reconstruct(shards, 'pass');
      expect(recovered, equals('max shards test'));
    });

    // TODO: Add real v0/v1 test vectors from the web app.
    // Run the web app locally, generate shards with a known secret/passphrase,
    // then paste the shard JSON strings here to verify cross-app compatibility.
    // This is critical for verifying pinenacl's SecretBox byte layout matches tweetnacl.

    test('unicode secret round-trip', () async {
      const secret = 'Hello World! Emoji support. CJK: \u4f60\u597d';
      final shardJsons = await BananaCrypto.share(
        data: secret,
        title: 'unicode',
        passphrase: 'test-pass',
        totalShards: 3,
        requiredShards: 2,
      );

      final shards = shardJsons.sublist(0, 2).map(Shard.parse).toList();
      final recovered = await BananaCrypto.reconstruct(shards, 'test-pass');
      expect(recovered, equals(secret));
    });
  });
}
```

- [ ] **Step 2: Run all tests**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
cd /home/mezinster/banana_split
git add banana_split_flutter/test/integration_test.dart
git commit -m "feat: add end-to-end integration tests for full create/restore flow"
```

---

### Task 17: Final build verification

- [ ] **Step 1: Run full analysis**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter analyze
```

Expected: No analysis issues.

- [ ] **Step 2: Run all tests**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter test
```

Expected: All tests PASS.

- [ ] **Step 3: Verify Android APK builds**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter build apk --debug
```

Expected: APK builds successfully.

- [ ] **Step 4: Verify Linux desktop builds (if on Linux)**

```bash
cd /home/mezinster/banana_split/banana_split_flutter && flutter build linux --debug
```

Expected: Linux binary builds successfully.
