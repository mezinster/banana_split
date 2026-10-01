import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the iOS project settings nothing in Dart notices going missing: a
/// missing usage string makes iOS terminate the app on the first camera or
/// photo access, and a missing PERMISSION_CAMERA macro makes
/// `Permission.camera.request()` answer permanentlyDenied without ever asking.
void main() {
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final pbxproj =
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final podfile = File('ios/Podfile').readAsStringSync();

  const usageKeys = [
    'NSCameraUsageDescription',
    'NSPhotoLibraryUsageDescription',
  ];

  final locales = Directory('lib/l10n')
      .listSync()
      .map((e) => RegExp(r'app_(\w+)\.arb$').firstMatch(e.path)?.group(1))
      .whereType<String>()
      .toList()
    ..sort();

  test('finds the app locales', () {
    expect(locales, contains('en'));
  });

  for (final key in usageKeys) {
    test('Info.plist declares $key', () {
      expect(
        RegExp('<key>$key</key>\\s*<string>[^<]+</string>').hasMatch(infoPlist),
        isTrue,
      );
    });
  }

  test('asks for no microphone access', () {
    // camera is only used for still frames; a microphone string would invite
    // the prompt and an App Review question for nothing.
    expect(infoPlist, isNot(contains('NSMicrophoneUsageDescription')));
  });

  for (final lang in locales) {
    test('$lang.lproj/InfoPlist.strings translates both usage strings', () {
      final file = File('ios/Runner/$lang.lproj/InfoPlist.strings');
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      final strings = file.readAsStringSync();
      for (final key in usageKeys) {
        expect(RegExp('"$key"\\s*=\\s*"[^"]+";').hasMatch(strings), isTrue,
            reason: '$key in ${file.path}');
      }
    });

    test('$lang is a known region with a variant in the project', () {
      final regions = RegExp(r'knownRegions = \((.*?)\);', dotAll: true)
          .firstMatch(pbxproj)!
          .group(1)!;
      expect(RegExp('\\b$lang\\b').hasMatch(regions), isTrue);
      expect(pbxproj, contains('path = $lang.lproj/InfoPlist.strings;'));
    });
  }

  test('Runner bundle id comes from BSPL_BUNDLE_ID', () {
    expect(pbxproj, contains(r'PRODUCT_BUNDLE_IDENTIFIER = "$(BSPL_BUNDLE_ID)";'));
    for (final config in ['Debug', 'Release']) {
      expect(
        File('ios/Flutter/$config.xcconfig').readAsStringSync(),
        contains('BSPL_BUNDLE_ID = com.nfcarchiver.bananasplit'),
      );
    }
  });

  test('commits no development team', () {
    // A team id belongs in the gitignored Flutter/LocalOverrides.xcconfig.
    expect(pbxproj, isNot(contains('DEVELOPMENT_TEAM')));
  });

  test('Podfile enables permission_handler camera support', () {
    expect(podfile, contains("'PERMISSION_CAMERA=1'"));
  });
}
