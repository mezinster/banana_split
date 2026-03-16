import 'dart:math';

class PassphraseGenerator {
  final List<String> _wordlist;
  final Random _rng = Random.secure();

  PassphraseGenerator(this._wordlist);

  String generate(int wordCount) {
    final words = <String>[];
    for (int i = 0; i < wordCount; i++) {
      final index = _rng.nextInt(65536) % 2048;
      words.add(_wordlist[index]);
    }
    return words.join('-');
  }

  factory PassphraseGenerator.fromString(String wordlistContent) {
    final words = wordlistContent
        .split('\n')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    return PassphraseGenerator(words);
  }
}
