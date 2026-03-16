import 'package:flutter_test/flutter_test.dart';
import 'package:banana_split_flutter/crypto/passphrase.dart';

void main() {
  group('PassphraseGenerator', () {
    test('generates correct number of words', () {
      final wordlist = List.generate(2048, (i) => 'word$i');
      final generator = PassphraseGenerator(wordlist);
      final result = generator.generate(4);
      expect(result.split('-').length, equals(4));
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
      expect(results.toSet().length, greaterThan(1));
    });

    test('fromString factory works', () {
      final content = List.generate(2048, (i) => 'word$i').join('\n');
      final gen = PassphraseGenerator.fromString(content);
      final result = gen.generate(4);
      expect(result.split('-').length, equals(4));
    });
  });
}
