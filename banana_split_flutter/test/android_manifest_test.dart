import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the manifest entries Open / Share depend on. Nothing in Dart fails
/// when one goes missing — the chooser just comes up nearly empty on Android
/// 11+, or the merged APK quietly gains permissions.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('declares package visibility for ACTION_VIEW on any MIME type', () {
    final queries =
        RegExp(r'<queries>(.*?)</queries>', dotAll: true).firstMatch(manifest);
    expect(queries, isNotNull, reason: 'no <queries> block');
    final intent = RegExp(
      r'<intent>\s*<action android:name="android.intent.action.VIEW"\s*/>'
      r'\s*<data android:mimeType="\*/\*"\s*/>\s*</intent>',
    );
    expect(intent.hasMatch(queries!.group(1)!), isTrue);
  });

  // READ_EXTERNAL_STORAGE matters most: it would apply through API 32 (the
  // only other storage permission, camerax's WRITE, stops at API 28), and a
  // secret-sharing app should not acquire a read permission as a side effect
  // of a plugin that only ever opens the app's own files.
  for (final permission in [
    'READ_EXTERNAL_STORAGE',
    'READ_MEDIA_IMAGES',
    'READ_MEDIA_VIDEO',
    'READ_MEDIA_AUDIO',
  ]) {
    test('strips $permission merged in by open_filex', () {
      final removal = RegExp(
        '<uses-permission\\s+android:name="android.permission.$permission"'
        '\\s+tools:node="remove"\\s*/>',
      );
      expect(removal.hasMatch(manifest), isTrue);
    });
  }

  // Google datatransport (ML Kit's telemetry, via mobile_scanner) declares
  // these to upload usage events. The app makes no network calls of its own,
  // and without them the listing's "no server communication" is enforced by
  // the OS rather than promised. Verified on a Pixel 8 Pro (Android 16):
  // scanning works, and datatransport logs a warning per event and gives up.
  for (final permission in ['INTERNET', 'ACCESS_NETWORK_STATE']) {
    test('strips $permission merged in by ML Kit', () {
      final removal = RegExp(
        '<uses-permission\\s+android:name="android.permission.$permission"'
        '\\s+tools:node="remove"\\s*/>',
      );
      expect(removal.hasMatch(manifest), isTrue);
    });
  }

  // camera_android_camerax declares these for video recording and for saving
  // captures to shared storage. The app does neither: it grabs still frames
  // into its cache directory to decode QR codes (issue #1).
  for (final permission in ['RECORD_AUDIO', 'WRITE_EXTERNAL_STORAGE']) {
    test('strips $permission merged in by the camera plugin', () {
      final removal = RegExp(
        '<uses-permission\\s+android:name="android.permission.$permission"'
        '\\s+tools:node="remove"\\s*/>',
      );
      expect(removal.hasMatch(manifest), isTrue);
    });
  }

  // Stripping RECORD_AUDIO is only safe while no CameraController asks for
  // audio: `enableAudio` defaults to TRUE, and with the permission gone the
  // controller would fail to initialise - i.e. the scanner would break. Both
  // scanner variants are checked; F-Droid builds the .fdroid one.
  for (final path in [
    'lib/widgets/shard_scanner.dart',
    'lib/widgets/shard_scanner.dart.fdroid',
  ]) {
    test('every CameraController in $path disables audio', () {
      final source = File(path).readAsStringSync();
      final controllers = RegExp(r'CameraController\(').allMatches(source);
      expect(controllers, isNotEmpty);
      for (final match in controllers) {
        final end = source.indexOf(');', match.start);
        expect(
          source.substring(match.start, end),
          contains('enableAudio: false'),
          reason: 'CameraController at offset ${match.start} in $path',
        );
      }
    });
  }
}
