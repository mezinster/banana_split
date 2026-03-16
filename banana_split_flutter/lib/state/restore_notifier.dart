import 'package:flutter/foundation.dart';
import 'package:banana_split_flutter/crypto/crypto.dart';
import 'package:banana_split_flutter/models/shard.dart';

class RestoreNotifier extends ChangeNotifier {
  final List<Shard> _shards = [];
  final Set<String> _rawCodes = {};
  String _passphrase = '';
  String? _recoveredSecret;
  bool _isDecrypting = false;
  String? _error;

  String get passphrase => _passphrase;
  String? get recoveredSecret => _recoveredSecret;
  bool get isDecrypting => _isDecrypting;
  String? get error => _error;

  int get scannedCount => _shards.length;

  int get requiredCount {
    if (_shards.isEmpty) return 0;
    return _shards.first.requiredShards;
  }

  String get title {
    if (_shards.isEmpty) return '';
    return _shards.first.title;
  }

  bool get needMoreShards => _shards.isEmpty || _shards.length < requiredCount;

  /// Attempts to add a shard from raw QR data.
  /// Returns null on success, or an error message string on failure.
  String? addShard(String rawQrData) {
    if (rawQrData.trim().isEmpty) {
      return 'QR code is empty.';
    }

    if (_rawCodes.contains(rawQrData)) {
      return 'This shard has already been scanned.';
    }

    Shard shard;
    try {
      shard = Shard.parse(rawQrData);
    } on FormatException catch (e) {
      return 'Failed to parse shard: ${e.message}';
    } catch (e) {
      return 'Failed to parse shard: $e';
    }

    if (_shards.isNotEmpty) {
      final first = _shards.first;
      if (shard.title != first.title) {
        return 'Title mismatch: expected "${first.title}", got "${shard.title}".';
      }
      if (shard.nonce != first.nonce) {
        return 'Nonce mismatch: this shard belongs to a different secret.';
      }
      if (shard.requiredShards != first.requiredShards) {
        return 'Required shards mismatch: this shard belongs to a different set.';
      }
      if (shard.version != first.version) {
        return 'Version mismatch: this shard belongs to a different set.';
      }
    }

    _shards.add(shard);
    _rawCodes.add(rawQrData);
    _error = null;
    notifyListeners();
    return null;
  }

  void updatePassphrase(String value) {
    _passphrase = value;
    notifyListeners();
  }

  Future<void> reconstruct() async {
    if (_shards.isEmpty) return;

    _isDecrypting = true;
    _error = null;
    notifyListeners();

    try {
      // Normalize passphrase: split on spaces, filter empty parts, join with hyphens
      final normalizedPassphrase = _passphrase
          .split(' ')
          .where((part) => part.isNotEmpty)
          .join('-');

      _recoveredSecret = await BananaCrypto.reconstruct(
        List.unmodifiable(_shards),
        normalizedPassphrase,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isDecrypting = false;
      notifyListeners();
    }
  }

  void reset() {
    _shards.clear();
    _rawCodes.clear();
    _passphrase = '';
    _recoveredSecret = null;
    _isDecrypting = false;
    _error = null;
    notifyListeners();
  }
}
