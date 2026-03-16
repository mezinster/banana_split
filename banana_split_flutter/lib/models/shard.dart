import 'dart:convert';

class Shard {
  final int version;
  final String title;
  final int requiredShards;
  final String data;
  final String nonce;

  const Shard({
    required this.version, required this.title, required this.requiredShards,
    required this.data, required this.nonce,
  });

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

  String toJson() {
    final map = {'v': version, 't': title, 'r': requiredShards, 'd': data, 'n': nonce};
    final jsonStr = jsonEncode(map);
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
