import 'dart:math';

/// Shamir's Secret Sharing over GF(2^bits).
///
/// Port of secrets.js-grempe to pure Dart.
/// Produces output compatible with the JS library.
class Shamir {
  final int bits;
  late final int size; // 2^bits
  late final int maxShares; // size - 1
  late final List<int> logs;
  late final List<int> exps;

  // Primitive polynomials for GF(2^bits), keyed by bits.
  static const Map<int, int> _primitives = {
    3: 3,
    4: 3,
    5: 5,
    6: 3,
    7: 3,
    8: 29,
    9: 17,
    10: 9,
    11: 5,
    12: 83,
    13: 27,
    14: 43,
    15: 3,
    16: 45,
    17: 9,
    18: 39,
    19: 39,
    20: 3,
  };

  Shamir({required this.bits}) {
    if (bits < 3 || bits > 20) {
      throw ArgumentError('bits must be between 3 and 20');
    }
    size = 1 << bits; // 2^bits
    maxShares = size - 1;
    _initTables();
  }

  void _initTables() {
    final primitive = _primitives[bits]!;
    logs = List<int>.filled(size, 0);
    exps = List<int>.filled(size, 0);

    int x = 1;
    for (int i = 0; i < size; i++) {
      exps[i] = x;
      logs[x] = i;
      x = x << 1;
      if (x >= size) {
        x = x ^ (size | primitive);
      }
    }
  }

  /// Evaluate polynomial with [coeffs] at point [x] using Horner's method.
  /// All arithmetic in GF(2^bits).
  int _horner(int x, List<int> coeffs) {
    final logx = logs[x];
    int fx = 0;
    for (int i = coeffs.length - 1; i >= 0; i--) {
      if (fx != 0) {
        fx = exps[(logx + logs[fx]) % maxShares] ^ coeffs[i];
      } else {
        fx = coeffs[i];
      }
    }
    return fx;
  }

  /// Lagrange interpolation at point [at] given points (x[i], y[i]).
  int _lagrange(int at, List<int> x, List<int> y) {
    int sum = 0;
    for (int i = 0; i < x.length; i++) {
      if (y[i] == 0) continue;
      int product = logs[y[i]];
      bool skip = false;
      for (int j = 0; j < x.length; j++) {
        if (i == j) continue;
        if (at == x[j]) {
          // If interpolating at one of the known x values
          skip = true;
          break;
        }
        product = (product + logs[at ^ x[j]] - logs[x[i] ^ x[j]] + maxShares) % maxShares;
      }
      if (!skip) {
        sum = sum ^ exps[product];
      }
    }
    return sum;
  }

  /// Number of hex characters needed to represent a value up to [maxShares].
  int get _idHexLen => (maxShares.toRadixString(16)).length;

  /// Split [hexSecret] into [numShares] shares, requiring [threshold] to reconstruct.
  List<String> share(String hexSecret, int numShares, int threshold) {
    if (numShares < 2) throw ArgumentError('numShares must be >= 2');
    if (threshold < 2) throw ArgumentError('threshold must be >= 2');
    if (threshold > numShares) throw ArgumentError('threshold must be <= numShares');
    if (numShares > maxShares) throw ArgumentError('numShares exceeds maxShares ($maxShares)');

    // Convert hex to binary string
    final hexStr = hexSecret.toLowerCase();
    final binBuf = StringBuffer();
    for (int i = 0; i < hexStr.length; i++) {
      binBuf.write(int.parse(hexStr[i], radix: 16).toRadixString(2).padLeft(4, '0'));
    }

    // Prepend '1' marker bit, then pad to multiple of bits (for secrets.js compat: pad to 128-bit chunks)
    String binary = '1$binBuf';
    // Pad to multiple of 128 bits (secrets.js pads to config.bits * 16 = 128 for bits=8)
    final padMultiple = bits * 16; // 128 for bits=8
    final remainder = binary.length % padMultiple;
    if (remainder > 0) {
      binary = binary.padLeft(binary.length + (padMultiple - remainder), '0');
    }

    // Split into segments of `bits` size
    final segments = <int>[];
    for (int i = 0; i < binary.length; i += bits) {
      segments.add(int.parse(binary.substring(i, i + bits), radix: 2));
    }

    final rng = Random.secure();

    // For each share x=1..numShares, compute y for each segment
    // shares[shareIndex][segmentIndex] = y value
    final shareValues = List<List<int>>.generate(numShares, (_) => <int>[]);

    for (int segIdx = 0; segIdx < segments.length; segIdx++) {
      // Build polynomial: coeffs[0] = secret segment, coeffs[1..threshold-1] = random
      final coeffs = <int>[segments[segIdx]];
      for (int c = 1; c < threshold; c++) {
        coeffs.add(rng.nextInt(maxShares) + 1); // 1..maxShares
      }

      for (int s = 0; s < numShares; s++) {
        final x = s + 1; // share IDs are 1-based
        shareValues[s].add(_horner(x, coeffs));
      }
    }

    // Encode shares
    final bitsChar = bits.toRadixString(36); // base36 encoding of bits
    final idLen = _idHexLen;

    final result = <String>[];
    for (int s = 0; s < numShares; s++) {
      final id = (s + 1).toRadixString(16).padLeft(idLen, '0');

      // Convert y-values to binary, then to hex
      final yBinBuf = StringBuffer();
      for (final y in shareValues[s]) {
        yBinBuf.write(y.toRadixString(2).padLeft(bits, '0'));
      }
      final yBin = yBinBuf.toString();

      // Convert binary string to hex
      final hexBuf = StringBuffer();
      for (int i = 0; i < yBin.length; i += 4) {
        hexBuf.write(int.parse(yBin.substring(i, i + 4), radix: 2).toRadixString(16));
      }

      result.add('$bitsChar$id${hexBuf.toString()}');
    }

    return result;
  }

  /// Reconstruct a hex secret from [shares].
  String combine(List<String> shares) {
    if (shares.isEmpty) throw ArgumentError('No shares provided');

    final idLen = _idHexLen;

    // Parse shares
    final xs = <int>[];
    final shareSegments = <List<int>>[];

    for (final share in shares) {
      // First char is bits in base36
      final shareBits = int.parse(share[0], radix: 36);
      if (shareBits != bits) {
        throw ArgumentError('Share bits mismatch: expected $bits, got $shareBits');
      }

      final id = int.parse(share.substring(1, 1 + idLen), radix: 16);
      final dataHex = share.substring(1 + idLen);

      // Convert hex data to binary
      final binBuf = StringBuffer();
      for (int i = 0; i < dataHex.length; i++) {
        binBuf.write(int.parse(dataHex[i], radix: 16).toRadixString(2).padLeft(4, '0'));
      }
      final binary = binBuf.toString();

      // Split into segments of `bits` size
      final segs = <int>[];
      for (int i = 0; i < binary.length; i += bits) {
        segs.add(int.parse(binary.substring(i, i + bits), radix: 2));
      }

      xs.add(id);
      shareSegments.add(segs);
    }

    // Lagrange interpolate each segment at x=0
    final numSegments = shareSegments[0].length;
    final recoveredBinBuf = StringBuffer();

    for (int seg = 0; seg < numSegments; seg++) {
      final yVals = <int>[];
      for (int s = 0; s < shares.length; s++) {
        yVals.add(shareSegments[s][seg]);
      }
      final val = _lagrange(0, xs, yVals);
      recoveredBinBuf.write(val.toRadixString(2).padLeft(bits, '0'));
    }

    final recoveredBin = recoveredBinBuf.toString();

    // Find the '1' marker bit and strip everything before and including it
    final markerIdx = recoveredBin.indexOf('1');
    if (markerIdx == -1) return '';

    final secretBin = recoveredBin.substring(markerIdx + 1);
    if (secretBin.isEmpty) return '';

    // Convert binary to hex
    // If length isn't a multiple of 4, this is likely garbage from insufficient shares
    if (secretBin.length % 4 != 0) return secretBin; // Return raw to ensure != original

    final hexBuf = StringBuffer();
    for (int i = 0; i < secretBin.length; i += 4) {
      hexBuf.write(int.parse(secretBin.substring(i, i + 4), radix: 2).toRadixString(16));
    }

    return hexBuf.toString();
  }
}
