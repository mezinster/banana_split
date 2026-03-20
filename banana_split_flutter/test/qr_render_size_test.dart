import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:banana_split_flutter/models/shard.dart';

/// Replicates the render-size calculation from ExportService._qrToPng
/// so we can test the mathematical invariants without needing the Flutter
/// rendering engine.
({int qrSize, int modulePixels, int padding}) calculateQrRenderSize(
  String data, {
  int size = 800,
}) {
  final qrCode = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final moduleCount = qrCode.moduleCount;

  final maxQrArea = size - 2 * (size * 0.08).round();
  final modulePixels = maxQrArea ~/ moduleCount;
  final qrSize = modulePixels * moduleCount;
  final padding = (size - qrSize) ~/ 2;

  return (qrSize: qrSize, modulePixels: modulePixels, padding: padding);
}

/// Simulates qr_flutter's _PaintMetrics rounding to detect overflow.
/// Returns true if the QR would overflow the container (the bug we fixed).
bool wouldOverflowWithOldCode(String data, {int size = 800}) {
  final qrCode = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final moduleCount = qrCode.moduleCount;
  final containerSize = size - 2 * (size * 0.08).round(); // 672 for size=800

  // Old code: QrPainter renders at fixed containerSize, qr_flutter rounds
  // pixelSize to nearest 0.5px which can cause overflow
  final rawPixelSize = containerSize / moduleCount;
  final roundedPixelSize = (rawPixelSize * 2).roundToDouble() / 2;
  final innerContentSize = roundedPixelSize * moduleCount;

  return innerContentSize > containerSize;
}

/// Creates a realistic shard JSON payload for testing.
String buildShardJson(String title) {
  // Use realistic-sized shard data (similar to actual Shamir shares)
  final fakeData = 'A${base64Encode(List.filled(200, 0x42))}';
  final fakeNonce = base64Encode(List.filled(24, 0x01));
  final shard = Shard(
    version: 2,
    title: title,
    requiredShards: 3,
    data: fakeData,
    nonce: fakeNonce,
  );
  return shard.toJson();
}

void main() {
  // Titles in all supported app languages plus edge cases
  final multilingualTitles = {
    'English': 'My Secret Backup Key',
    'Russian': 'Код на русском языке',
    'Ukrainian': 'Український секрет',
    'Belarusian': 'Беларускі сакрэт',
    'Turkish': 'Türkçe gizli anahtar',
    'Georgian': 'ქართული საიდუმლო',
    'Mixed Latin+Cyrillic': 'Wallet Кошелёк 2024',
    'Emoji': '🔑 Secret Key 🔐',
    'Long Cyrillic': 'Очень длинное название секрета на русском языке для проверки',
    'Short': 'X',
    'CJK': '秘密鍵のバックアップ',
    'Arabic': 'مفتاح سري للنسخ الاحتياطي',
  };

  group('QR render size — pixel-perfect for all languages', () {
    for (final entry in multilingualTitles.entries) {
      test('${entry.key} title: "${entry.value}"', () {
        final json = buildShardJson(entry.value);
        final result = calculateQrRenderSize(json);
        final qrCode = QrCode.fromData(
          data: json,
          errorCorrectLevel: QrErrorCorrectLevel.M,
        );

        // Key invariant: render size is an exact multiple of module count
        expect(
          result.qrSize % qrCode.moduleCount,
          equals(0),
          reason: 'Render size ${result.qrSize} is not a multiple of '
              'module count ${qrCode.moduleCount}',
        );

        // Fits within available area (800 - 2*64 = 672)
        expect(result.qrSize, lessThanOrEqualTo(672));

        // Module pixel size is large enough for reliable scanning
        expect(
          result.modulePixels,
          greaterThanOrEqualTo(5),
          reason: 'Module pixel size ${result.modulePixels} is too small '
              'for reliable QR scanning',
        );

        // Padding is non-negative (quiet zone)
        expect(result.padding, greaterThanOrEqualTo(0));
      });
    }
  });

  group('QR render size — old code overflow detection', () {
    test('old code causes overflow for at least one Cyrillic title', () {
      // Prove the bug existed: at least one Cyrillic title would have
      // caused qr_flutter to render the QR code larger than its container
      var foundOverflow = false;
      for (final entry in multilingualTitles.entries) {
        final json = buildShardJson(entry.value);
        if (wouldOverflowWithOldCode(json)) {
          foundOverflow = true;
          // Verify our fix handles this case correctly
          final result = calculateQrRenderSize(json);
          final qrCode = QrCode.fromData(
            data: json,
            errorCorrectLevel: QrErrorCorrectLevel.M,
          );
          expect(result.qrSize % qrCode.moduleCount, equals(0));
          expect(result.qrSize, lessThanOrEqualTo(672));
        }
      }
      // At least one title should trigger the overflow with the old code
      expect(foundOverflow, isTrue,
          reason: 'Expected at least one title to trigger overflow with '
              'old rendering code');
    });

    test('new code never overflows for any QR version', () {
      // Exhaustively test all 40 QR versions
      for (int version = 1; version <= 40; version++) {
        final moduleCount = 4 * version + 17;
        const size = 800;
        final maxQrArea = size - 2 * (size * 0.08).round();
        final modulePixels = maxQrArea ~/ moduleCount;
        final qrSize = modulePixels * moduleCount;

        expect(
          qrSize % moduleCount,
          equals(0),
          reason: 'QR version $version (${moduleCount}x$moduleCount modules) '
              'has non-integer pixel size',
        );
        expect(
          qrSize,
          lessThanOrEqualTo(maxQrArea),
          reason: 'QR version $version exceeds available area '
              '($qrSize > $maxQrArea)',
        );

        if (moduleCount <= maxQrArea) {
          expect(
            modulePixels,
            greaterThanOrEqualTo(1),
            reason: 'QR version $version has zero-size modules',
          );
        }
      }
    });
  });

  group('QR render size — unicode expansion in shard JSON', () {
    test('Cyrillic title produces larger QR version than Latin title', () {
      final latinJson = buildShardJson('Secret');
      final cyrillicJson = buildShardJson('Секрет');

      // Cyrillic JSON is larger due to \\uXXXX escaping in toJson()
      expect(cyrillicJson.length, greaterThan(latinJson.length),
          reason: 'Unicode-escaped Cyrillic should be longer than Latin');

      final latinQr = QrCode.fromData(
        data: latinJson,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final cyrillicQr = QrCode.fromData(
        data: cyrillicJson,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );

      // Cyrillic version should be >= Latin version (more data = higher version)
      expect(cyrillicQr.typeNumber, greaterThanOrEqualTo(latinQr.typeNumber));
    });

    test('toJson unicode escaping preserves roundtrip fidelity', () {
      for (final entry in multilingualTitles.entries) {
        final shard = Shard(
          version: 2,
          title: entry.value,
          requiredShards: 3,
          data: 'Aabc',
          nonce: 'bm9uY2U=',
        );
        final json = shard.toJson();

        // Parse it back and verify the title survived the roundtrip
        final parsed = Shard.parse(json);
        expect(
          parsed.title,
          equals(entry.value),
          reason: '${entry.key} title roundtrip failed',
        );
      }
    });
  });
}
