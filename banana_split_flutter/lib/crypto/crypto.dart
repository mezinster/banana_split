import 'dart:convert';
import 'dart:isolate';

import 'package:pinenacl/tweetnacl.dart';
import 'package:pinenacl/api.dart';
import 'package:pointycastle/export.dart';

import 'package:banana_split_flutter/crypto/shamir.dart';
import 'package:banana_split_flutter/models/shard.dart';

class BananaCrypto {
  BananaCrypto._();

  /// SHA-512 hash of a string.
  static Uint8List _hashString(String str) {
    final data = Uint8List.fromList(utf8.encode(str));
    final out = Uint8List(64);
    TweetNaCl.crypto_hash(out, data);
    return out;
  }

  /// Encode bytes as lowercase hex string.
  static String _hexify(Uint8List arr) {
    return arr.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Decode hex string to bytes.
  static Uint8List _dehexify(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16);
    }
    return result;
  }

  /// Derive a 32-byte key from passphrase and salt using scrypt.
  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final scrypt = KeyDerivator('scrypt')
      ..init(ScryptParameters(1 << 15, 8, 1, 32, salt));
    return scrypt.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// Encrypt data with NaCl secretbox (XSalsa20-Poly1305).
  /// Returns the ciphertext (MAC + encrypted) and random nonce.
  static ({Uint8List value, Uint8List nonce}) _encrypt(
      String data, Uint8List salt, String passphrase) {
    final key = _deriveKey(passphrase, salt);
    final nonce = PineNaClUtils.randombytes(24);
    final plainBytes = Uint8List.fromList(utf8.encode(data));

    // Pad plaintext with 32 zero bytes as required by crypto_secretbox
    final m = Uint8List(32 + plainBytes.length);
    m.setRange(32, 32 + plainBytes.length, plainBytes);

    final c = Uint8List(m.length);
    // crypto_secretbox returns c.sublist(16): MAC (16 bytes) + ciphertext
    final result = TweetNaCl.crypto_secretbox(c, m, m.length, nonce, key);

    return (value: Uint8List.fromList(result), nonce: nonce);
  }

  /// Decrypt data with NaCl secretbox. Returns null on failure.
  static Uint8List? _decrypt(
      Uint8List data, Uint8List salt, String passphrase, Uint8List nonce) {
    final key = _deriveKey(passphrase, salt);

    // Prepend 16 zero bytes to data (the format crypto_secretbox_open expects)
    final c = Uint8List(16 + data.length);
    c.setRange(16, 16 + data.length, data);

    final m = Uint8List(c.length);
    try {
      // crypto_secretbox_open returns m.sublist(32): the plaintext
      final result =
          TweetNaCl.crypto_secretbox_open(m, c, c.length, nonce, key);
      return Uint8List.fromList(result);
    } catch (_) {
      // Throws on MAC verification failure
      return null;
    }
  }

  /// The synchronous core of share() — separated so it can run in an Isolate.
  static List<String> _shareSync({
    required String data,
    required String title,
    required String passphrase,
    required int totalShards,
    required int requiredShards,
  }) {
    final salt = _hashString(title);
    final encrypted = _encrypt(data, salt, passphrase);

    final nonceB64 = base64Encode(encrypted.nonce);
    final hexEncrypted = _hexify(encrypted.value);

    final shamir = Shamir(bits: 8);
    final shamirShares = shamir.share(hexEncrypted, totalShards, requiredShards);

    final result = <String>[];
    for (final share in shamirShares) {
      final bitfieldChar = share[0];
      final hexData = share.substring(1);
      final encodedShard = bitfieldChar + base64Encode(_dehexify(hexData));

      final shard = Shard(
        version: 2,
        title: title,
        requiredShards: requiredShards,
        data: encodedShard,
        nonce: nonceB64,
      );
      result.add(shard.toJson());
    }

    return result;
  }

  /// Split secret data into Shamir shards, returning JSON strings.
  /// Runs heavy crypto (scrypt) in a separate Isolate to keep the UI responsive.
  static Future<List<String>> share({
    required String data,
    required String title,
    required String passphrase,
    required int totalShards,
    required int requiredShards,
  }) {
    return Isolate.run(() => _shareSync(
          data: data,
          title: title,
          passphrase: passphrase,
          totalShards: totalShards,
          requiredShards: requiredShards,
        ));
  }

  /// The synchronous core of reconstruct() — separated so it can run in an Isolate.
  static String _reconstructSync(
      List<Map<String, dynamic>> shardMaps, String passphrase) {
    // Rehydrate Shard objects inside the isolate
    final shardObjects = shardMaps
        .map((m) => Shard(
              version: m['version'] as int,
              title: m['title'] as String,
              requiredShards: m['requiredShards'] as int,
              data: m['data'] as String,
              nonce: m['nonce'] as String,
            ))
        .toList();

    Shard.validateCompatibility(shardObjects);

    final first = shardObjects.first;
    if (shardObjects.length < first.requiredShards) {
      throw 'Not enough shards: need ${first.requiredShards}, got ${shardObjects.length}';
    }

    final salt = _hashString(first.title);
    final shamir = Shamir(bits: 8);

    Uint8List ciphertext;
    Uint8List nonce;

    if (first.version == 0) {
      nonce = _dehexify(first.nonce);
      final shamirShares = shardObjects.map((s) => s.data).toList();
      final hexSecret = shamir.combine(shamirShares);
      ciphertext = _dehexify(hexSecret);
    } else {
      nonce = base64Decode(first.nonce);
      final shamirShares = shardObjects.map((s) {
        final bitfieldChar = s.data[0];
        final b64Data = s.data.substring(1);
        final hexData = _hexify(Uint8List.fromList(base64Decode(b64Data)));
        return bitfieldChar + hexData;
      }).toList();
      final hexSecret = shamir.combine(shamirShares);
      ciphertext = _dehexify(hexSecret);
    }

    final result = _decrypt(ciphertext, salt, passphrase, nonce);
    if (result == null) {
      throw 'Unable to decrypt the secret. Wrong passphrase or corrupted data.';
    }

    return utf8.decode(result);
  }

  /// Reconstruct the original secret from shard objects and passphrase.
  /// Runs heavy crypto (scrypt) in a separate Isolate to keep the UI responsive.
  static Future<String> reconstruct(
      List<Shard> shardObjects, String passphrase) {
    // Serialize Shard objects to Maps for cross-isolate transfer
    // (Shard instances can't be sent directly across isolate boundaries)
    final shardMaps = shardObjects
        .map((s) => {
              'version': s.version,
              'title': s.title,
              'requiredShards': s.requiredShards,
              'data': s.data,
              'nonce': s.nonce,
            })
        .toList();

    return Isolate.run(() => _reconstructSync(shardMaps, passphrase));
  }
}
