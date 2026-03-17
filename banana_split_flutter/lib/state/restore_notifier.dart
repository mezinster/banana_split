import 'package:flutter/foundation.dart';
import 'package:banana_split_flutter/crypto/crypto.dart';
import 'package:banana_split_flutter/models/shard.dart';

sealed class ShardError {
  const ShardError();
}

class EmptyQrError extends ShardError {
  const EmptyQrError();
}

class DuplicateShardError extends ShardError {
  const DuplicateShardError();
}

class ParseError extends ShardError {
  final String detail;
  const ParseError(this.detail);
}

class TitleMismatchError extends ShardError {
  final String expected;
  final String actual;
  const TitleMismatchError(this.expected, this.actual);
}

class NonceMismatchError extends ShardError {
  const NonceMismatchError();
}

class RequiredMismatchError extends ShardError {
  const RequiredMismatchError();
}

class VersionMismatchError extends ShardError {
  const VersionMismatchError();
}

class DecryptionError extends ShardError {
  const DecryptionError();
}

class NotEnoughShardsError extends ShardError {
  final int required;
  final int got;
  const NotEnoughShardsError(this.required, this.got);
}

class RestoreNotifier extends ChangeNotifier {
  final List<Shard> _shards = [];
  final Set<String> _rawCodes = {};
  String _passphrase = '';
  String? _recoveredSecret;
  bool _isDecrypting = false;
  ShardError? _error;

  String get passphrase => _passphrase;
  String? get recoveredSecret => _recoveredSecret;
  bool get isDecrypting => _isDecrypting;
  ShardError? get error => _error;

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
  /// Returns null on success, or a ShardError on failure.
  ShardError? addShard(String rawQrData) {
    if (rawQrData.trim().isEmpty) {
      return const EmptyQrError();
    }

    if (_rawCodes.contains(rawQrData)) {
      return const DuplicateShardError();
    }

    Shard shard;
    try {
      shard = Shard.parse(rawQrData);
    } on FormatException catch (e) {
      return ParseError(e.message);
    } catch (e) {
      return ParseError(e.toString());
    }

    if (_shards.isNotEmpty) {
      final first = _shards.first;
      if (shard.title != first.title) {
        return TitleMismatchError(first.title, shard.title);
      }
      if (shard.nonce != first.nonce) {
        return const NonceMismatchError();
      }
      if (shard.requiredShards != first.requiredShards) {
        return const RequiredMismatchError();
      }
      if (shard.version != first.version) {
        return const VersionMismatchError();
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
      final msg = e.toString();
      if (msg.contains('Not enough shards')) {
        final match = RegExp(r'need (\d+), got (\d+)').firstMatch(msg);
        if (match != null) {
          _error = NotEnoughShardsError(
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
          );
        } else {
          _error = const DecryptionError();
        }
      } else {
        _error = const DecryptionError();
      }
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
